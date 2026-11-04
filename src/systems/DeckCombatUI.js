class DeckCombatUI {
  static isPathSynergyTransformListSupported(value) {
    const source = String(value || 'none').trim();
    if (source === 'none' || /^matrix\([^()]+\)$/.test(source)) return true;
    const calls = [...source.matchAll(/([a-zA-Z]+)\([^()]*\)/g)];
    if (!calls.length || source.replace(/([a-zA-Z]+)\([^()]*\)/g, '').trim()) return false;
    let previous = 0, rotations = 0, scales = 0;
    for (const call of calls) {
      const rank = /^(translate|translateX|translateY)$/.test(call[1]) ? 1
        : /^(rotate|rotateZ)$/.test(call[1]) ? 2 : /^(scale|scaleX|scaleY)$/.test(call[1]) ? 3 : 0;
      if (!rank || rank < previous || (rank === 2 && ++rotations > 1) || (rank === 3 && ++scales > 1)) return false;
      previous = rank;
    }
    return true;
  }

  static pathSynergyTransformRange(current, frames) {
    const decompose = m => {
      const sx = Math.hypot(m.a, m.b), sy = (m.a * m.d - m.b * m.c) / sx;
      if (!(sx > 0 && sy > 0) || Math.abs(m.a * m.c + m.b * m.d) > 1e-5 * sx * sy)
        throw new Error('Unsupported skew/singular synergy obstacle transform');
      return { sx, sy, angle: Number.isFinite(m.angle) ? m.angle : Math.atan2(m.b, m.a), x: m.e, y: m.f };
    };
    const base = decompose(current), poses = [base, ...frames.map(decompose)];
    const turn = Math.max(...poses.map(p => Math.abs(p.angle - base.angle)));
    // ||Rf Df - Rc Dc|| <= ||Df-Dc|| + ||Rf-Rc|| ||Dc||.
    // This bounds every interpolated angle, including extrema BETWEEN keys.
    const drift = Math.max(...poses.map(p => Math.max(Math.abs(p.sx - base.sx), Math.abs(p.sy - base.sy))))
      + Math.max(base.sx, base.sy) * 2 * Math.sin(Math.min(Math.PI, turn) / 2);
    const lo = Math.min(...poses.map(p => p.angle)), hi = Math.max(...poses.map(p => p.angle));
    const trigMax = (fn, peak) => Math.ceil((lo - peak) / Math.PI) <= Math.floor((hi - peak) / Math.PI)
      ? 1 : Math.max(Math.abs(fn(lo)), Math.abs(fn(hi)));
    const cos = trigMax(Math.cos, 0), sin = trigMax(Math.sin, Math.PI / 2);
    const sx = Math.max(...poses.map(p => p.sx)), sy = Math.max(...poses.map(p => p.sy));
    return { drift, tx: Math.max(...poses.map(p => Math.abs(p.x - base.x))),
      ty: Math.max(...poses.map(p => Math.abs(p.y - base.y))),
      abs: { a: cos * sx, b: sin * sx, c: sin * sy, d: cos * sy } };
  }

  static boundPathSynergySweep(rect, motions) {
    let dx = 0, dy = 0;
    for (const motion of motions) {
      const range = DeckCombatUI.pathSynergyTransformRange(motion.current, motion.frames);
      const rotationScale = range.drift * motion.pointRadius;
      const x = range.tx + rotationScale, y = range.ty + rotationScale, o = motion.outer;
      // Telescoping the nested transform product uses CURRENT inner points
      // and FUTURE outer bounds. This includes parent/child cross terms.
      dx += o.a * x + o.c * y; dy += o.b * x + o.d * y;
    }
    return { left: rect.left - dx, right: rect.right + dx, top: rect.top - dy, bottom: rect.bottom + dy,
      width: rect.width + dx * 2, height: rect.height + dy * 2 };
  }

  _pathSynergySweptRect(element, rect) {
    if (typeof DOMMatrixReadOnly === 'undefined' || !element?.getAnimations) return rect;
    const chain = [];
    const matrix = value => {
      const m = new DOMMatrixReadOnly(!value || value === 'none' ? undefined : value);
      if (!m.is2D) throw new Error('Unsupported 3D synergy obstacle transform');
      // Explicit rotate() can describe a whole turn which a matrix would lose.
      const turns = [...String(value).matchAll(/rotate(?:Z)?\(\s*(-?[\d.]+)(deg|rad|turn)\s*\)/g)];
      if (turns.length === 1) m._authoredAngle = Number(turns[0][1])
        * ({ deg: Math.PI / 180, rad: 1, turn: Math.PI * 2 }[turns[0][2]]);
      return m;
    };
    const plain = m => ({ a: m.a, b: m.b, c: m.c, d: m.d, e: m.e, f: m.f,
      ...(Number.isFinite(m._authoredAngle) ? { angle: m._authoredAngle } : {}) });
    const multiply = (x, y) => ({ a: x.a * y.a + x.c * y.b, b: x.b * y.a + x.d * y.b,
      c: x.a * y.c + x.c * y.d, d: x.b * y.c + x.d * y.d });
    const identity = () => ({ a: 1, b: 0, c: 0, d: 1 });
    try {
      for (let node = element; node; node = node.parentElement) {
        const style = getComputedStyle(node), current = matrix(style.transform), frames = [];
        if (Number(style.zoom || 1) !== 1 || [style.translate, style.rotate, style.scale].some(v => v && v !== 'none'))
          throw new Error('Unsupported individual transform/zoom in synergy obstacle');
        for (const animation of node.getAnimations()) {
          if (animation.effect?.target !== node || !['running', 'pending'].includes(animation.playState)) continue;
          const keys = animation.effect.getKeyframes();
          if (!keys.some(k => k.transform !== undefined)) continue;
          if ((animation.effect.composite && animation.effect.composite !== 'replace')
            || animation.effect.iterationComposite === 'accumulate'
            || keys.some(k => k.transform !== undefined && !DeckCombatUI.isPathSynergyTransformListSupported(k.transform)))
            throw new Error('Unsupported transform function order/composition in synergy obstacle');
          const easingSafe = easing => /^(linear|ease|ease-in|ease-out|ease-in-out|steps\([^)]*\))$/.test(easing || 'linear')
            || (() => { const v = String(easing).match(/^cubic-bezier\(([^)]+)\)$/)?.[1].split(',').map(Number);
              return v?.length === 4 && v.every(n => n >= 0 && n <= 1); })();
          if (!easingSafe(animation.effect.getTiming().easing) || keys.some(k => !easingSafe(k.easing)
            || (k.composite && !['auto', 'replace'].includes(k.composite)) || k.transformOrigin !== undefined))
            throw new Error('Unsupported overshoot/composite/origin animation in synergy obstacle');
          for (const key of keys) if (key.transform !== undefined) frames.push(plain(matrix(key.transform)));
        }
        const currentPlain = plain(current);
        const range = frames.length ? DeckCombatUI.pathSynergyTransformRange(currentPlain, frames) : null;
        chain.push({ node, style, current, currentPlain, frames, range });
      }
      let outerCurrent = identity(), outerFuture = identity();
      const motions = [];
      for (let i = chain.length - 1; i >= 0; i--) {
        const item = chain[i], full = multiply(outerCurrent, item.current);
        if (item.frames.length) {
          const r = item.node.getBoundingClientRect(), s = item.style;
          const extra = axis => s.boxSizing === 'border-box' ? 0 : axis === 'x'
            ? parseFloat(s.paddingLeft) + parseFloat(s.paddingRight) + parseFloat(s.borderLeftWidth) + parseFloat(s.borderRightWidth)
            : parseFloat(s.paddingTop) + parseFloat(s.paddingBottom) + parseFloat(s.borderTopWidth) + parseFloat(s.borderBottomWidth);
          const width = parseFloat(s.width) + extra('x'), height = parseFloat(s.height) + extra('y');
          const origin = s.transformOrigin.split(' ').map(parseFloat);
          if (![width, height, ...origin.slice(0, 2)].every(Number.isFinite)) throw new Error('Unmeasurable synergy transform origin');
          // Affine rectangles are centrally symmetric. Their DOM AABB centre
          // is the transformed border-box centre, even under nested rotations.
          const ox = origin[0] - width / 2, oy = origin[1] - height / 2;
          const center = { x: (r.left + r.right) / 2 + full.a * ox + full.c * oy,
            y: (r.top + r.bottom) / 2 + full.b * ox + full.d * oy };
          const det = full.a * full.d - full.b * full.c;
          if (Math.abs(det) < 1e-9) throw new Error('Singular synergy ancestor');
          let pointRadius = 0;
          for (const x of [rect.left, rect.right]) for (const y of [rect.top, rect.bottom]) {
            const dx = x - center.x, dy = y - center.y;
            pointRadius = Math.max(pointRadius, Math.hypot((full.d * dx - full.c * dy) / det,
              (-full.b * dx + full.a * dy) / det));
          }
          motions.push({ current: item.currentPlain, frames: item.frames, pointRadius, outer: outerFuture });
        }
        outerCurrent = full;
        outerFuture = multiply(outerFuture, item.range?.abs || { a: Math.abs(item.current.a), b: Math.abs(item.current.b),
          c: Math.abs(item.current.c), d: Math.abs(item.current.d) });
      }
      return DeckCombatUI.boundPathSynergySweep(rect, motions);
    } catch (error) {
      // Keep the existing presentation, but make unsupported geometry an
      // explicit acceptance failure rather than quietly claiming safety.
      this.container.dataset.pathSynergySweepError = String(error.message || error);
      return rect;
    }
  }

  static resolvePathSynergyRect({ size, body, identity = null, bounds, obstacles = [] }) {
    if (!size || !body || !bounds || !(size.width > 0) || !(size.height > 0)) return null;
    const gap = 8, width = size.width, height = size.height;
    const ceiling = Math.min(body.top, identity?.top ?? body.top) - gap;
    const preferredX = body.left + body.width / 2 - width / 2;
    const preferredY = ceiling - height;
    const xs = [preferredX, bounds.left, bounds.right - width,
      ...obstacles.flatMap(rect => [rect.left - width - gap, rect.right + gap])];
    const ys = [preferredY, bounds.top, ...obstacles.map(rect => rect.top - height - gap)];
    let best = null, score = Infinity;
    for (const x of xs) for (const y of ys) {
      const rect = { left: x, top: y, right: x + width, bottom: y + height, width, height };
      if (rect.left < bounds.left || rect.right > bounds.right || rect.top < bounds.top
        || rect.bottom > Math.min(bounds.bottom, ceiling)) continue;
      if (obstacles.some(o => rect.left < o.right + gap && rect.right > o.left - gap
        && rect.top < o.bottom + gap && rect.bottom > o.top - gap)) continue;
      const distance = (x - preferredX) ** 2 + (y - preferredY) ** 2;
      if (distance < score) { best = rect; score = distance; }
    }
    return best;
  }

  static buildPathSynergyViewModel(receipt) {
    const feedback = receipt?.feedback;
    const activations = receipt?.activations;
    if (!receipt?.settlementId || !['blade', 'cycle', 'fortress', 'cauldron'].includes(feedback?.shape)
      || !Array.isArray(activations) || !activations.length
      || activations.some(item => !item?.ruleId || !item.text)) return null;
    const details = [];
    for (const item of activations) {
      const damage = Number(item.consumption?.damageBonus) || 0;
      const block = Number(item.consumption?.blockBonus) || 0;
      if (damage > 0) details.push(`增伤 +${damage} 已计入本招`);
      else if (Number(item.requestedDelta?.damageBonus) > 0) details.push('本张增伤未使用');
      if (block > 0) details.push(`格挡加成 +${block} 已计入本招`);
      else if (Number(item.requestedDelta?.blockBonus) > 0) details.push('本张格挡加成未使用');
      if (Number(item.requestedDelta?.gainQi) > 0) {
        const qi = Number(item.appliedDelta?.gainQi) || 0;
        details.push(qi > 0 ? `真元实际 +${qi}` : '真元 +0（上限）');
      }
    }
    return { shape: feedback.shape, title: activations.map(item => item.text).join(' · '),
      condition: [...new Set(activations.map(item => String(item.conditionText || feedback.conditionText || '')).filter(Boolean))].join(' · '), details };
  }

  static resolveCombatDossierAsset(kind, item = {}) {
    if (kind === 'companion') return item.cardArt || {};
    if (item.objectArt?.image) return item.objectArt;
    return item.cardArt || {};
  }

  static buildCombatFeedbackViewModel(data = {}) {
    const dictionary = {
      damage: { label: '气血', caption: '攻势命中', tone: 'damage', sigil: '破', sign: 'negative' },
      backlash: { label: '反噬', caption: '气机逆冲', tone: 'damage', sigil: '噬', sign: 'negative' },
      shield: { label: '护盾', caption: '护体成势', tone: 'shield', sigil: '护', sign: 'positive' },
      blocked: { label: '格挡', caption: '攻势化解', tone: 'shield', sigil: '守', sign: 'none' },
      heal: { label: '护体', caption: '气脉回转', tone: 'heal', sigil: '生', sign: 'positive' },
      weak: { label: '虚弱', caption: '气势受制', tone: 'status', sigil: '弱', sign: 'positive' },
      vulnerable: { label: '易伤', caption: '破绽显露', tone: 'status', sigil: '隙', sign: 'positive' },
      opening: { label: '破绽', caption: '下一击 +1', tone: 'status', sigil: '隙', sign: 'positive' },
      opening_consumed: { label: '乘隙', caption: '追击命中', tone: 'focus', sigil: '锋', sign: 'positive' },
      sword_intent: { label: '剑意', caption: '锋芒凝聚', tone: 'focus', sigil: '剑', sign: 'positive' },
      spell_seal: { label: '法印', caption: '术式成形', tone: 'focus', sigil: '印', sign: 'positive' },
      qi: { label: '真元', caption: '灵息回流', tone: 'focus', sigil: '元', sign: 'positive' }
    };
    const contract = dictionary[String(data.feedbackId || '')]
      || { label: '战局变化', caption: '气机流转', tone: 'neutral', sigil: '变', sign: 'none' };
    const numeric = Number(data.value);
    let valueText = '';
    if (Number.isFinite(numeric) && numeric !== 0) {
      const magnitude = Math.abs(numeric);
      if (contract.sign === 'positive') valueText = `+${magnitude}`;
      else if (contract.sign === 'negative') valueText = `-${magnitude}`;
      else valueText = String(numeric);
    } else if (contract.sign === 'none') {
      valueText = data.valueText ? String(data.valueText) : '';
    }
    return {
      label: contract.label,
      valueText,
      caption: data.caption ? String(data.caption) : contract.caption,
      tone: contract.tone,
      sigil: contract.sigil
    };
  }

  constructor() {
    this.container = document.getElementById('deck-combat-screen');

    // 缓存 DOM 节点
    this.enemyName = document.getElementById('combat-enemy-name');
    this.enemyIntent = document.getElementById('combat-enemy-intent');
    this.enemyHearts = document.getElementById('combat-enemy-hearts');
    this.enemyStatus = document.getElementById('combat-enemy-status');
      this.enemyContainer = this.container ? this.container.querySelector('.enemy-area') : null;
      this.enemySprite = document.getElementById('combat-enemy-sprite');
      this.enemyPortrait = document.getElementById('combat-enemy-portrait');
      this.enemyKicker = document.getElementById('combat-enemy-kicker');
      this.playerSprite = document.getElementById('combat-player-sprite');
      this.playerPortrait = document.getElementById('combat-player-portrait');
      this.enemyActorCard = document.getElementById('combat-enemy-sprite-container');
      this.playerActorCard = document.getElementById('combat-player-sprite-container');
    this.playerName = document.getElementById('combat-player-name');
    this.playerKicker = document.getElementById('combat-player-kicker');
    this.playerTreasure = document.getElementById('combat-player-treasure');
    this.playerTreasureArt = document.getElementById('combat-player-treasure-art');
    this.playerTreasureName = document.getElementById('combat-player-treasure-name');
    this.playerTreasureSummary = document.getElementById('combat-player-treasure-summary');
    this.treasureInspector = document.getElementById('combat-treasure-inspector');
    this.treasureInspectorBackdrop = document.getElementById('combat-treasure-inspector-backdrop');
    this.treasureInspectorClose = document.getElementById('combat-treasure-inspector-close');
    this.treasureInspectorArt = document.getElementById('combat-treasure-inspector-art');
    this.treasureInspectorEyebrow = document.getElementById('combat-treasure-inspector-eyebrow');
    this.treasureInspectorName = document.getElementById('combat-treasure-inspector-name');
    this.treasureInspectorId = document.getElementById('combat-treasure-inspector-id');
    this.treasureInspectorSummary = document.getElementById('combat-treasure-inspector-summary');
    this.treasureInspectorFacts = document.getElementById('combat-treasure-inspector-facts');
    this.treasureInspectorCard = document.getElementById('combat-treasure-inspector-card');
    this.treasureInspectorTrigger = document.getElementById('combat-treasure-inspector-trigger');
    this.dossierDock = document.getElementById('combat-dossier-dock');
    this.companionRoster = document.getElementById('combat-companion-roster');
    this.treasureRoster = document.getElementById('combat-treasure-roster');
    this.companionCount = document.getElementById('combat-companion-count');
    this.treasureCount = document.getElementById('combat-treasure-count');
    this.dossierMechanismLabel = document.getElementById('combat-dossier-mechanism-label');
    this.dossierPrev = document.getElementById('combat-dossier-prev');
    this.dossierNext = document.getElementById('combat-dossier-next');
    this.dossierCounter = document.getElementById('combat-dossier-counter');
    this.threatBadge = document.getElementById('combat-threat-badge');
    this.turnBadge = document.getElementById('combat-turn-badge');
    this.infoToggle = document.getElementById('combat-info-toggle');
    this.mechanic = document.getElementById('combat-mechanic');
    this.decisionFacts = null;

    this.playerHearts = document.getElementById('combat-player-hearts');
    this.playerStatus = document.getElementById('combat-player-status');
    this.playerContainer = this.container ? this.container.querySelector('.player-area') : null;

    this.qiVal = document.getElementById('combat-qi-val');
    this.maxQiVal = document.getElementById('combat-max-qi-val');
    this.qiLabel = document.getElementById('combat-qi-label');

    this.drawCount = document.getElementById('combat-draw-count');
    this.discardCount = document.getElementById('combat-discard-count');
    this.exhaustCount = document.getElementById('combat-exhaust-count');

    this.handContainer = document.getElementById('combat-player-hand');
    this.logsContainer = document.getElementById('deck-combat-logs');
    this.equipmentProgress = document.getElementById('combat-equipment-progress');

    this.endTurnBtn = document.getElementById('combat-end-turn-btn');
    this.fleeBtn = document.getElementById('combat-flee-btn');
    this.reactionPanel = document.getElementById('combat-reaction-panel');
    this.reactionKicker = document.getElementById('combat-reaction-kicker');
    this.reactionTitle = document.getElementById('combat-reaction-title');
    this.reactionMode = document.getElementById('combat-reaction-mode');
    this.reactionAction = document.getElementById('combat-reaction-action');
    this.reactionDescription = document.getElementById('combat-reaction-description');
    this.reactionDamage = document.getElementById('combat-reaction-damage');
    this.reactionOptions = document.getElementById('combat-reaction-options');
    this.reactionHelp = document.getElementById('combat-reaction-help');
    this.reactionLive = document.getElementById('combat-reaction-live');
    this.atmosphere = document.getElementById('combat-atmosphere');
    this.entryBanner = document.getElementById('combat-entry-banner');
    this.entryTitle = document.getElementById('combat-entry-title');
    this.entrySubtitle = document.getElementById('combat-entry-subtitle');
    this.actionLayer = document.getElementById('combat-action-layer');
    this.exchangeStage = document.getElementById('combat-exchange-stage');
    this.stagePresenter = typeof CombatStagePresenter !== 'undefined'
      ? new CombatStagePresenter({
        root: this.container,
        stage: this.exchangeStage,
        playerArea: this.playerContainer,
        enemyArea: this.enemyContainer
      })
      : null;
    this._currentContext = {};
    this._currentIntent = null;
    this._lastEncounterId = null;
    this._lastEncounterInstanceId = null;
    this._fleeArmed = false;
    this._fleeTimer = null;
    this._dossierKind = null;
    this._dossierIndex = 0;
    this._dossierOpener = null;
    this._activeReaction = null;
    this._lastReactionWindowId = null;
    this._reactionCountdownTimer = null;
    this._combatLiveTimer = null;
    this._sceneImageSource = null;
    this._sceneLoadToken = 0;
    this._semanticActionRuns = new Map();
    // A defeated actor's final authored frame is passive battlefield state,
    // not an active action. Keep it outside the serialized action queue so the
    // victor can finish while the defeated body remains visibly defeated.
    this._terminalActorResidues = new Map();
    // A player reaction completes before the authoritative enemy body action
    // begins. Retain its final authored pose only for that follow-through so
    // attack, contact VFX and defence read as one exchange instead of two
    // unrelated solo animations.
    this._reactionActorResidues = new Map();
    // Presentation-only reactions can be followed by a synchronous hurt event
    // before the browser receives a paint opportunity. Keep that visual-only
    // continuation separate from authoritative DeckCombatSystem state.
    this._semanticPresentationQueues = new Map();
    this._terminalPresentationHideTimer = null;
    this._semanticPresentationOrder = 0;
    this._bossPhasePresentationRuns = new Map();
    this._seenBossPhaseEventIds = new Set();
    this._preloadedSemanticFrames = new Set();
    this._preloadedImages = new Map();
    this._seenVfxEventIds = new Set();
    // Stage FX funnel counters. Presentation-only: an authored hit may be
    // refused by geometry or by a travel-scale contract, and those were
    // previously indistinguishable. Counts let a real combat run report how
    // far an action travelled instead of inferring it from missing pixels.
    this._stageFxFunnel = {
      actionStarted: 0,
      startRegistered: 0,
      startRefused: 0,
      vfxRequested: 0,
      vfxStaged: 0,
      vfxRefused: 0,
      impactFired: 0,
      impactRefused: 0,
      skippedNoActor: 0,
      skippedNoActionId: 0
    };
    // Serialized body choreography can defer a visible action after the
    // combat system has already emitted its VFX. Keep both on the same
    // presentation clock so a projectile never arrives before actor geometry.
    this._pendingVfxByActionId = new Map();
    this._pendingVfxDecodeByActionId = new Map();
    this._suppressedVfxActionIds = new Set();
    this._pendingPathSynergyByActionId = new Map();
    this._seenPathSynergyIds = new Set();
    this._pathSynergyCues = new Map();
    this._pathSynergyEpoch = 0;
    this._pathSynergyRestGeometry = null;
    this._reducedMotion = typeof window !== 'undefined' && window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    this._worldLayoutFrame = null;
    this._worldResizeHandler = () => {
      if (!this._currentContext?.visualWorldCompatible) return;
      if (this._worldLayoutFrame && typeof cancelAnimationFrame === 'function') cancelAnimationFrame(this._worldLayoutFrame);
      const apply = () => {
        this._worldLayoutFrame = null;
        this._applyVisualWorldContext(this._currentContext, this._currentIntent);
      };
      this._worldLayoutFrame = typeof requestAnimationFrame === 'function'
        ? requestAnimationFrame(apply)
        : setTimeout(apply, 16);
    };

    this.init();
  }

  init() {
    if (!this.container) return;

    if (typeof window !== 'undefined') window.addEventListener('resize', this._worldResizeHandler, { passive: true });

    // 监听逻辑层更新
    eventBus.on('combat:started', () => {
      // A rejected settlement can restore the same encounter instance. Its
      // prior visual work is abandoned even though render sees the same ID.
      clearTimeout(this._terminalPresentationHideTimer);
      this._terminalPresentationHideTimer = null;
      this._clearAllSemanticActions();
    });
    eventBus.on('combat:updated', (data) => this.render(data));
    eventBus.on('combat:anim', (data) => this.playAnim(data));
    eventBus.on('combat:vfx', (data) => this.playVfx(data));
    eventBus.on('combat:actionStarted', (data) => this._onSemanticActionStarted(data));
    eventBus.on('combat:impact', (data) => this._onSemanticImpact(data));
    eventBus.on('combat:actionCompleted', (data) => this._onSemanticActionCompleted(data));
    eventBus.on('combat:cardCommitted', (data) => this.playCardCommit(data));
    eventBus.on('combat:pathSynergyResolved', (data) => this._onPathSynergyResolved(data));
    eventBus.on('combat:storyAssistCommitted', (data) => this.playStoryAssist(data));
    eventBus.on('combat:treasureTriggered', (data) => this.playTreasureTrigger(data));
    eventBus.on('combat:reactionResolved', (data) => this._announceReactionResult(data));
    eventBus.on('combat:reactionMissed', () => this._announceReactionMissed());
    eventBus.on('combat:planTransition', (data) => this._announcePlanTransition(data));
    eventBus.on('combat:bossPhaseChanged', (data) => this._onBossPhaseChanged(data));
    eventBus.on('ui:hideCombatScreen', () => {
      if (this._terminalPresentationHideTimer) clearTimeout(this._terminalPresentationHideTimer);
      this._terminalPresentationHideTimer = null;
      this._closeTreasureInspector({ restoreFocus: false });
      this._setInfoExpanded(false);
      if (this.decisionFacts) this.decisionFacts.open = false;
      this._clearReactionCountdown();
      this._clearCombatLive();
      this._clearAllSemanticActions();
      this.stagePresenter?.destroy();
      this._seenVfxEventIds.clear();
      if (typeof document !== 'undefined') delete document.documentElement.dataset.combatAmbientGlow;
      this._clearBossPhasePresentations({ resetSeen: true });
      this._activeReaction = null;
      if (this.reactionPanel) this.reactionPanel.hidden = true;
    });

    // 绑定按钮事件
    if (this.endTurnBtn) this.endTurnBtn.addEventListener('click', () => {
       if (typeof deckCombatSystem !== 'undefined') {
           deckCombatSystem.endTurn();
       }
    });
    if (this.fleeBtn) this.fleeBtn.addEventListener('click', () => this._requestFlee());
    if (this.infoToggle) this.infoToggle.addEventListener('click', () => {
      this._setInfoExpanded(this.container?.dataset.infoExpanded !== 'true');
    });
    if (this.playerTreasure) this.playerTreasure.addEventListener('click', () => this._openTreasureInspector());
    if (this.treasureInspectorBackdrop) {
      this.treasureInspectorBackdrop.addEventListener('click', () => this._closeTreasureInspector());
    }
    if (this.treasureInspectorClose) {
      this.treasureInspectorClose.addEventListener('click', () => this._closeTreasureInspector());
    }
    if (this.dossierPrev) this.dossierPrev.addEventListener('click', () => this._stepCombatDossier(-1));
    if (this.dossierNext) this.dossierNext.addEventListener('click', () => this._stepCombatDossier(1));
    document.addEventListener('keydown', (event) => this._handleKeydown(event));

    // A restored combat can become active before this delayed UI consumer has
    // subscribed to `combat:updated`. Reconcile from the authoritative combat
    // state once on initialization so a reload never leaves an otherwise active
    // combat screen with its actor bays and hand unrendered.
    if (typeof deckCombatSystem !== 'undefined'
      && deckCombatSystem?.active
      && typeof deckCombatSystem.getState === 'function') {
      this.render(deckCombatSystem.getState());
    }
  }

  _isActive() {
    return !!(this.container && this.container.classList.contains('active'));
  }

  _ownsPathSynergyReceipt(receipt) {
    return this._isActive() && receipt?.encounterInstanceId === this._lastEncounterInstanceId
      && typeof gameState !== 'undefined'
      && receipt.lifeId === gameState.runClock?.lifeId
      && receipt.saveSlotId === gameState.getActiveSaveSlotId?.();
  }

  _onPathSynergyResolved(receipt) {
    if (!this._ownsPathSynergyReceipt(receipt)
      || !DeckCombatUI.buildPathSynergyViewModel(receipt)
      || this._seenPathSynergyIds.has(receipt.settlementId)) return;
    this._seenPathSynergyIds.add(receipt.settlementId);
    const copy = JSON.parse(JSON.stringify(receipt));
    const queued = [...this._semanticPresentationQueues.values()]
      .some(queue => queue.some(item => item.actionId === copy.actionId));
    if (queued) this._pendingPathSynergyByActionId.set(copy.actionId, copy);
    else this._mountPathSynergyCue(copy);
  }

  _flushPathSynergyForAction(actionId) {
    const receipt = this._pendingPathSynergyByActionId?.get(actionId);
    if (!receipt) return;
    this._pendingPathSynergyByActionId.delete(actionId);
    this._mountPathSynergyCue(receipt);
  }

  _mountPathSynergyCue(receipt) {
    if (!this._ownsPathSynergyReceipt(receipt)) return;
    const view = DeckCombatUI.buildPathSynergyViewModel(receipt);
    if (!view) return;
    const epoch = this._pathSynergyEpoch;
    const node = document.createElement('div');
    node.className = 'combat-path-synergy';
    node.dataset.pathSynergyId = receipt.settlementId;
    node.dataset.synergyShape = view.shape;
    node.setAttribute('role', 'status');
    node.setAttribute('aria-live', 'polite');
    const sigil = document.createElement('span');
    sigil.className = 'path-synergy-sigil';
    sigil.setAttribute('aria-hidden', 'true');
    const markCount = view.shape === 'cycle' ? 3 : view.shape === 'fortress' ? 2 : 1;
    for (let i = 0; i < markCount; i++) sigil.appendChild(document.createElement('i'));
    const copy = document.createElement('span');
    copy.className = 'path-synergy-copy';
    for (const [tag, text] of [['strong', view.title], ['span', view.condition],
      ...view.details.map(text => ['small', text])]) {
      const line = document.createElement(tag); line.textContent = text; copy.appendChild(line);
    }
    node.append(sigil, copy);
    const run = { node, timer: null };
    this._pathSynergyCues.set(receipt.settlementId, run);
    const mounted = () => {
      if (epoch !== this._pathSynergyEpoch || !this._ownsPathSynergyReceipt(receipt)
        || this._pathSynergyCues.get(receipt.settlementId) !== run) {
        node.remove(); return;
      }
      // Stage owns the impact mount, but its short action cleanup must not
      // own this longer explanation. UI reset/hide and the dwell timer do.
      node.dataset.pathSynergyActionId = String(receipt.actionId || '');
      delete node.dataset.combatStageActionId;
      // New genuine receipts replace the previous explanation, never stack
      // several opaque panels over the same actor. Replay does not extend it.
      for (const [id, other] of this._pathSynergyCues) {
        if (id === receipt.settlementId) continue;
        clearTimeout(other.timer); other.node.remove(); this._pathSynergyCues.delete(id);
      }
      // The stage's centerMass anchor controls when feedback arrives, not
      // where a multi-line explanation may cover the performing actor.
      run.reflow = () => {
      if (!node.parentElement) return false;
      const host = node.parentElement.getBoundingClientRect();
      const box = node.getBoundingClientRect();
      const left = Math.max(8, host.left), right = Math.min(innerWidth - 8, host.right);
      const top = Math.max(8, host.top), bottom = Math.min(innerHeight - 8, host.bottom);
      const visibleRect = element => {
        if (!element) return null;
        const style = getComputedStyle(element), rect = element.getBoundingClientRect();
        return style.display !== 'none' && style.visibility !== 'hidden' && Number(style.opacity) !== 0
          && rect.width > 0 && rect.height > 0 ? rect : null;
      };
      const body = visibleRect(this.playerActorCard);
      const resting = this._pathSynergyRestGeometry?.viewport === `${innerWidth}x${innerHeight}`
        ? this._pathSynergyRestGeometry : null;
      let dx = box.left < left ? left - box.left : Math.min(0, right - box.right);
      let dy = box.top < top ? top - box.top : Math.min(0, bottom - box.bottom);
      if (body) {
        const obstacles = [this.playerActorCard, this.enemyActorCard, this.playerKicker, this.enemyKicker,
          this.playerName, this.enemyName, this.playerHearts, this.enemyHearts, this.playerStatus, this.enemyStatus,
          this.enemyIntent, this.mechanic, this.logsContainer, this.handContainer,
          this.endTurnBtn, this.fleeBtn, this.qiVal?.closest('.combat-resources')]
          .map(element => { const rect = visibleRect(element); return rect ? this._pathSynergySweptRect(element, rect) : null; }).filter(Boolean);
        // Body actions temporarily hide kicker DOM. Its measured resting
        // region must remain reserved until the longer receipt has expired.
        obstacles.push(...(resting?.obstacles || []));
        const rawIdentity = visibleRect(this.playerKicker);
        const currentIdentity = rawIdentity ? this._pathSynergySweptRect(this.playerKicker, rawIdentity) : null;
        const identities = [currentIdentity, resting?.playerIdentity].filter(Boolean);
        const identity = identities.sort((a, b) => a.top - b.top)[0] || null;
        // Action boundaries can introduce new ancestor transforms while the
        // explanation is still alive. Keep its fixed position if still safe;
        // only a genuinely changed obstacle may cause one event-driven move.
        if (node.dataset.synergyPlacement === 'above-actor-clear'
          && box.left >= left && box.right <= right && box.top >= top && box.bottom <= bottom
          && box.bottom <= Math.min(body.top, identity?.top ?? body.top) - 8
          && obstacles.every(o => box.right <= o.left - 8 || box.left >= o.right + 8
            || box.bottom <= o.top - 8 || box.top >= o.bottom + 8)) return true;
        const safe = DeckCombatUI.resolvePathSynergyRect({ size: box, body,
          identity, bounds: { left, right, top, bottom }, obstacles });
        if (!safe) {
          node.remove(); this._pathSynergyCues.delete(receipt.settlementId);
          this.container.dataset.pathSynergyPlacement = 'no-clear-region';
          return false;
        }
        dx = safe.left - box.left; dy = safe.top - box.top;
        node.dataset.synergyPlacement = 'above-actor-clear';
        this.container.dataset.pathSynergyPlacement = 'above-actor-clear';
      }
      node.style.left = `${(parseFloat(node.style.left) || 0) + dx}px`;
      node.style.top = `${(parseFloat(node.style.top) || 0) + dy}px`;
      return true;
      };
      if (!run.reflow()) return;
      // Reduced motion changes movement, not the time available to read.
      run.timer = setTimeout(() => {
        node.remove(); this._pathSynergyCues.delete(receipt.settlementId);
      }, 2400);
    };
    if (!this.stagePresenter?.mountAtContact(node, {
      actionId: receipt.actionId, target: 'player', feedbackPlacement: 'target-clear'
    }, 'feedback', mounted)) {
      node.style.left = `${this.container.clientWidth / 2}px`;
      node.style.top = `${this.container.clientHeight / 2}px`;
      this.container.appendChild(node); mounted();
    }
  }

  _clearPathSynergyCues() {
    if (this.container) delete this.container.dataset.pathSynergySweepError;
    this._pathSynergyRestGeometry = null;
    this._pathSynergyEpoch = (this._pathSynergyEpoch || 0) + 1;
    this._pendingPathSynergyByActionId?.clear();
    this._seenPathSynergyIds?.clear();
    for (const run of this._pathSynergyCues?.values() || []) {
      clearTimeout(run.timer); run.node.remove();
    }
    this._pathSynergyCues?.clear();
  }

  _reflowPathSynergyCues() {
    // No RAF polling, remount, timer reset, actor writes or gameplay writes.
    for (const run of this._pathSynergyCues?.values() || []) run.reflow?.();
  }

  _handleKeydown(event) {
    // Native disclosure owns its reading keys. Escape closes the explanation,
    // never arms retreat; number keys here must not play a card or reaction.
    if (this.decisionFacts?.contains(event.target)) {
      if (event.key === 'Escape' && this.decisionFacts.open) {
        event.preventDefault();
        this.decisionFacts.open = false;
        this.mechanic.scrollTop = 0;
        this.decisionFacts.querySelector('summary')?.focus();
      }
      return;
    }
    if (event.key === 'Escape' && this.treasureInspector && !this.treasureInspector.hidden) {
      event.preventDefault();
      this._closeTreasureInspector();
      return;
    }
    if (!this.treasureInspector?.hidden && (event.key === 'ArrowLeft' || event.key === 'ArrowRight')) {
      event.preventDefault();
      this._stepCombatDossier(event.key === 'ArrowLeft' ? -1 : 1);
      return;
    }
    if (event.key === 'Escape' && this._isActive() && this.container?.dataset.infoExpanded === 'true') {
      event.preventDefault();
      this._setInfoExpanded(false);
      this.infoToggle?.focus();
      return;
    }
    if (!this._isActive() || event.altKey || event.ctrlKey || event.metaKey) return;
    if (this._activeReaction) {
      if (/^[1-9]$/.test(event.key)) {
        const index = Number(event.key) - 1;
        const option = this._activeReaction.options?.[index];
        if (option?.available && typeof deckCombatSystem !== 'undefined') {
          event.preventDefault();
          deckCombatSystem.chooseReaction(option.id, this._activeReaction.windowId);
        }
      } else if (event.key === 'Escape') {
        event.preventDefault();
        this._requestFlee();
      }
      return;
    }
    if (/^[1-5]$/.test(event.key)) {
      const index = Number(event.key) - 1;
      if (typeof deckCombatSystem !== 'undefined' && deckCombatSystem.active && deckCombatSystem.hand[index] !== undefined) {
        event.preventDefault();
        deckCombatSystem.playCard(index);
      }
    } else if (event.key.toLowerCase() === 'e') {
      event.preventDefault();
      if (typeof deckCombatSystem !== 'undefined') deckCombatSystem.endTurn();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      this._requestFlee();
    }
  }

  _requestFlee() {
    if (!this.fleeBtn || typeof deckCombatSystem === 'undefined' || !deckCombatSystem.active) return;
    if (!this._fleeArmed) {
      this._fleeArmed = true;
      // T-05：不再用 innerHTML 整体覆写按钮。纯文本覆写会销毁 <span>/<strong>/<kbd>，
      // 导致 combat-controls.css 的子元素选择器失配、grid 塌陷（这是记录在案的 P0）。
      this._setControlLabel(this.fleeBtn, '撤阵', '再次确认逃离', 'Esc');
      this.fleeBtn.classList.add('armed');
      clearTimeout(this._fleeTimer);
      this._fleeTimer = setTimeout(() => this._resetFleeButton(), 3000);
      return;
    }
    this._resetFleeButton();
    deckCombatSystem.flee();
  }

  _resetFleeButton() {
    this._fleeArmed = false;
    clearTimeout(this._fleeTimer);
    if (this.fleeBtn) {
      this._setControlLabel(this.fleeBtn, '撤阵', '逃离战场', 'Esc');
      this.fleeBtn.classList.remove('armed');
    }
  }

  _setInfoExpanded(expanded) {
    if (!this.container || !this.infoToggle) return;
    if (this._fleeArmed) this._resetFleeButton();
    this.container.dataset.infoExpanded = expanded ? 'true' : 'false';
    this.infoToggle.setAttribute('aria-expanded', String(expanded));
    this.infoToggle.setAttribute('aria-label', expanded ? '收起战局详情' : '展开战局详情');
    this.infoToggle.textContent = expanded ? '收起详情' : '战局详情';
  }

  // T-05：控件文本统一走结构化 DOM。只改 textContent，绝不动标签结构；
  // 结构若已被历史 innerHTML 覆写破坏，则按既定结构补回，保证样式选择器命中。
  _setControlLabel(button, kicker, label, key) {
    if (!button) return;
    let span = button.querySelector('span');
    let strong = button.querySelector('strong');
    let kbd = button.querySelector('kbd');
    if (!strong) {
      strong = document.createElement('strong');
      button.appendChild(strong);
    }
    if (!span) {
      span = document.createElement('span');
      button.insertBefore(span, strong);
    }
    if (!kbd && key) {
      kbd = document.createElement('kbd');
      button.appendChild(kbd);
    }
    if (kicker) span.textContent = kicker;
    if (label) strong.textContent = label;
    if (kbd && key) kbd.textContent = key;
  }

  _showEncounterIntro(context, enemyName) {
    if (!this._isActive()) return;
    const encounterId = context && context.cardId ? context.cardId : enemyName;
    if (!this.entryBanner || this._lastEncounterId === encounterId) return;
    this._lastEncounterId = encounterId;
    if (this.entryTitle) this.entryTitle.textContent = enemyName || '战局展开';
    if (this.entrySubtitle) this.entrySubtitle.textContent = (context && context.mechanic) || '凝神观势，择机出手';
    this.entryBanner.classList.remove('visible');
    void this.entryBanner.offsetWidth;
    this.entryBanner.classList.add('visible');
  }

  _clearActorWorldComposition(side) {
    const area = side === 'enemy' ? this.enemyContainer : this.playerContainer;
    const card = side === 'enemy' ? this.enemyActorCard : this.playerActorCard;
    const sprite = side === 'enemy' ? this.enemySprite : this.playerSprite;
    const portrait = side === 'enemy' ? this.enemyPortrait : this.playerPortrait;
    const properties = [
      '--actor-left', '--actor-top', '--actor-body-width', '--actor-body-height',
      '--actor-center-x', '--actor-ground-y', '--actor-z-index', '--actor-canvas-height', '--actor-canvas-width',
      '--actor-canvas-bottom', '--actor-canvas-x-bias', '--actor-action-canvas-height',
      '--actor-action-canvas-width', '--actor-action-canvas-bottom', '--actor-kicker-top',
      '--actor-shadow-width', '--actor-shadow-height', '--actor-shadow-bottom'
    ];
    properties.forEach(property => {
      area?.style?.removeProperty(property);
      card?.style?.removeProperty(property);
      portrait?.style?.removeProperty(property);
    });
    if (card) {
      delete card.dataset.scaleProfileId;
      delete card.dataset.massClass;
      delete card.dataset.canonicalHeightU;
      delete card.dataset.canonicalWidthU;
      delete card.dataset.authoredHeightRatio;
      delete card.dataset.authoredWidthRatio;
      delete card.dataset.centerMassHeightFromGround;
      delete card.dataset.rootMode;
      delete card.dataset.spatialContractId;
      delete card.dataset.authoredScaleBasis;
      delete card.dataset.bodyProfileContractSha256;
      delete card.dataset.compoundActor;
      delete card.dataset.viewportClampStatus;
      delete card.dataset.viewportFit;
      delete card.dataset.exchangeLayoutScale;
      delete card.dataset.totalUniformScale;
      delete card.dataset.maximumUniformShrinkRatio;
      delete card.dataset.exchangeEnvelope;
      delete card.dataset.motionEnvelope;
      delete card.dataset.exchangeChoreographyPolicyId;
      delete card.dataset.resolvedActorCenterX;
      delete card.dataset.maxRenderExtentU;
      delete card.dataset.resolvedRenderWidthPx;
      delete card.dataset.resolvedRenderHeightPx;
      delete card.dataset.resolvedBodyWidthPx;
      delete card.dataset.resolvedBodyHeightPx;
      delete card.dataset.bodyClass;
      delete card.dataset.visualThreatRank;
      delete card.dataset.groundingMode;
      delete card.dataset.shadowFootprintU;
      delete card.dataset.resolvedShadowWidthPx;
      delete card.dataset.resolvedShadowHeightPx;
      delete card.dataset.silhouetteTraits;
      delete card.dataset.worldGroundY;
      delete card.dataset.worldDepth;
      delete card.dataset.carrierMetricId;
      delete card.dataset.carrierAssetPath;
      delete card.dataset.bodyBounds;
      delete card.dataset.renderBounds;
      delete card.dataset.groundAnchor;
      delete card.dataset.contactAnchorStatus;
      delete card.dataset.encounterCompositionId;
      delete card.dataset.worldScaleStatus;
    }
    if (sprite) {
      delete sprite.dataset.scaleProfileId;
      delete sprite.dataset.visualWorldId;
    }
    if (area) {
      delete area.dataset.worldLayer;
      delete area.dataset.worldDepthBand;
      delete area.dataset.visualWorldId;
    }
    this.stagePresenter?.clearActorWorldContract?.(side);
  }

  _normaliseVisualAssetPath(source = '') {
    const raw = typeof source === 'string' ? source.trim() : '';
    if (!raw) return '';
    try {
      const parsed = new URL(raw, typeof window !== 'undefined' ? window.location.href : 'http://local.invalid/');
      return decodeURIComponent(parsed.pathname).replace(/^\/+/, '').replace(/\\/g, '/');
    } catch (_error) {
      return raw.replace(/^\/+/, '').replace(/\\/g, '/').split(/[?#]/, 1)[0];
    }
  }

  _resolveActorPortraitSource(side, actorCard = {}, intent = null) {
    if (side !== 'enemy' || actorCard.intentPosePolicy === 'stable_identity') {
      return typeof actorCard.image === 'string' ? actorCard.image : '';
    }
    return actorCard?.intentFrames?.[intent?.type] || actorCard.image || '';
  }

  _clearVisualWorldProperties() {
    if (!this.container) return;
    [
      '--world-ink', '--world-ink-soft', '--world-mid', '--world-paper-dim', '--world-paper',
      '--world-impact', '--world-cinnabar', '--world-intent', '--world-horizon-y', '--world-ground-y',
      '--world-battlefield-root-image',
      '--world-battlefield-focus-x', '--world-battlefield-focus-y', '--world-battlefield-zoom',
      '--world-ui-safe-x', '--world-ui-safe-y', '--world-ui-safe-width', '--world-ui-safe-height',
      '--world-ui-action-button-frame', '--world-ui-divider-joinery', '--world-ui-hand-card-frame',
      '--world-ui-hand-tray-frame', '--world-ui-health-slot-frame', '--world-ui-intent-tag-body',
      '--world-ui-intent-tag-notch', '--world-ui-qi-slot-frame', '--world-ui-resource-socket-frame',
      '--world-ui-status-ledger-panel', '--world-actor-lighting-filter', '--world-contact-shadow-color',
      '--combat-layer-background', '--combat-layer-grade', '--combat-layer-exchange', '--combat-layer-actors',
      '--combat-layer-labels', '--combat-layer-ui', '--combat-layer-action', '--combat-layer-overlay'
    ].forEach(property => this.container.style.removeProperty(property));
    [
      'worldUiMediaDensity', 'worldUiLogicalPixelGrid', 'worldUiReviewStatus',
      'worldUiFinalArtApproved', 'worldMaterialSurfaceCount', 'worldVfxAssetCount',
      'worldLightingId', 'contactShadowRenderer', 'contactShadowMediaDensity',
      'contactShadowLogicalPixelGrid', 'contactShadowReviewStatus',
      'resolvedPlayerScaleProfileId', 'resolvedEnemyScaleProfileId',
      'resolvedActorHeightRatio', 'resolvedActorWidthRatio', 'resolvedScaleContrastPolicy',
      'exchangeLayoutContractId', 'minimumExchangeGapPx', 'resolvedExchangeGapPx',
      'exchangeLayoutResolutionTrace', 'exchangeChoreographyPolicyId'
    ].forEach(key => delete this.container.dataset[key]);
    this.container.querySelectorAll('[data-world-ui-surface-id]').forEach(surface => {
      delete surface.dataset.worldUiSurfaceId;
      delete surface.dataset.mediaDensity;
      delete surface.dataset.logicalPixelGrid;
      delete surface.dataset.mediaReviewStatus;
    });
    if (this.atmosphere) {
      delete this.atmosphere.dataset.battlefieldProfileId;
      delete this.atmosphere.dataset.cropPolicy;
      delete this.atmosphere.dataset.mediaDensity;
      delete this.atmosphere.dataset.logicalPixelGrid;
      delete this.atmosphere.dataset.mediaReviewStatus;
    }
  }

  _isUnitNumber(value) {
    return typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 1;
  }

  _isUnitPoint(point) {
    return Boolean(point && this._isUnitNumber(point.x) && this._isUnitNumber(point.y));
  }

  _isUnitRect(rect) {
    return Boolean(rect
      && this._isUnitNumber(rect.x) && this._isUnitNumber(rect.y)
      && this._isUnitNumber(rect.width) && rect.width > 0
      && this._isUnitNumber(rect.height) && rect.height > 0
      && rect.x + rect.width <= 1.000001
      && rect.y + rect.height <= 1.000001);
  }

  _hasAuthoredContactAnchors(profile = {}) {
    return ['ground', 'centerMass', 'meleeLeft', 'meleeRight', 'castLeft', 'castRight']
      .every(anchor => this._isUnitPoint(profile?.contactAnchors?.[anchor]));
  }

  _isActorSpatialContractCompatible(profile = {}) {
    if (profile?.spatialContractId !== 'actor_spatial_v1') return false;
    const isFiniteNumber = value => typeof value === 'number' && Number.isFinite(value);
    const basis = profile?.authoredScaleBasis;
    const authoredBasisCompatible = ['speciesId', 'morphologyId', 'progressionStageId', 'combatRoleId']
      .every(field => typeof basis?.[field] === 'string' && basis[field].trim());
    const compound = profile?.compoundActor;
    const compoundCompatible = !compound || Boolean(
      compound.contractId === 'compound_actor_formation_v1'
      && compound.mode === 'single_combat_entity'
      && Number.isInteger(compound.memberCount) && compound.memberCount > 1
      && typeof compound.formationRootMode === 'string' && compound.formationRootMode.trim()
      && Number(compound?.formationBoundsU?.width) > 0
      && Number(compound?.formationBoundsU?.height) > 0
      && typeof compound.strikeOriginPolicy === 'string' && compound.strikeOriginPolicy.trim()
    );
    const centerMassHeight = Number(profile.centerMassHeightFromGround);
    const anchorCenterMassHeight = 1 - Number(profile?.contactAnchors?.centerMass?.y);
    const depth = profile?.depthEnvelope;
    const viewportClamp = profile?.viewportClamp;
    const exchangeFitPolicy = profile?.exchangeFitPolicy;
    const clampCompatible = ['narrow', 'desktop'].every(mode => {
      const clamp = viewportClamp?.[mode];
      return isFiniteNumber(clamp?.minReadableHeightPx) && clamp.minReadableHeightPx > 0
        && isFiniteNumber(clamp?.maxRenderedHeightVh)
        && clamp.maxRenderedHeightVh > 0 && clamp.maxRenderedHeightVh <= 1
        && isFiniteNumber(clamp?.maxRenderedWidthVw)
        && clamp.maxRenderedWidthVw > 0 && clamp.maxRenderedWidthVw <= 1;
    });
    const threatSources = profile?.threatSources;
    const hoverCompatible = profile.groundingMode !== 'shadow_projection'
      || (Number(profile?.hoverContract?.coreClearanceU) > 0
        && Number(profile?.hoverContract?.lowestFragmentClearanceU) >= 0
        && Number(profile.hoverContract.lowestFragmentClearanceU)
          <= Number(profile.hoverContract.coreClearanceU)
        && profile?.hoverContract?.shadowRoot === 'centroid');
    return Boolean(authoredBasisCompatible
      && /^[a-f0-9]{64}$/.test(String(profile.bodyProfileContractSha256 || ''))
      && compoundCompatible
      && isFiniteNumber(profile.centerMassHeightFromGround)
      && Number.isFinite(centerMassHeight) && centerMassHeight > 0 && centerMassHeight < 1
      && Number.isFinite(anchorCenterMassHeight)
      && Math.abs(centerMassHeight - anchorCenterMassHeight) <= 0.000001
      && isFiniteNumber(profile.authoredHeightRatio)
      && isFiniteNumber(profile.authoredWidthRatio)
      && Math.abs(profile.authoredHeightRatio - Number(profile.canonicalHeightU)) <= 0.000001
      && Math.abs(profile.authoredWidthRatio - Number(profile.canonicalWidthU)) <= 0.000001
      && typeof profile.rootMode === 'string' && profile.rootMode.trim()
      && isFiniteNumber(depth?.min) && isFiniteNumber(depth?.default) && isFiniteNumber(depth?.max)
      && Number(depth.min) >= -1 && Number(depth.max) <= 1
      && Number(depth.min) <= Number(depth.default) && Number(depth.default) <= Number(depth.max)
      && clampCompatible
      && typeof viewportClamp?.preserveThreatAxis === 'string'
      && viewportClamp.preserveThreatAxis.trim()
      && isFiniteNumber(exchangeFitPolicy?.maximumUniformShrinkRatio)
      && exchangeFitPolicy.maximumUniformShrinkRatio >= 0
      && exchangeFitPolicy.maximumUniformShrinkRatio < 1
      && exchangeFitPolicy.preserveAuthoredAspect === true
      && typeof exchangeFitPolicy.scalePriority === 'string'
      && exchangeFitPolicy.scalePriority.trim()
      && Array.isArray(threatSources) && threatSources.length >= 2
      && threatSources.every((source, index) => typeof source?.source === 'string'
        && source.source.trim() && Number.isInteger(source.priority) && source.priority === index + 1)
      && hoverCompatible);
  }

  _isAuthoredScaleOverrideCompatible(profile = {}, world = {}, requiredDimensions = []) {
    const override = profile?.authoredOverride;
    const contract = world?.authoringScalePolicy?.authoredOverrideContract;
    const changedDimensions = override?.changedDimensions;
    const allowedDimensions = new Set(Array.isArray(contract?.allowedDimensions)
      ? contract.allowedDimensions : []);
    const forbiddenStrategies = new Set(Array.isArray(contract?.forbiddenStrategies)
      ? contract.forbiddenStrategies : []);
    return Boolean(contract
      && override
      && typeof override.reason === 'string' && override.reason.trim()
      && typeof override.silhouetteStrategy === 'string' && override.silhouetteStrategy.trim()
      && !forbiddenStrategies.has(override.silhouetteStrategy)
      && Array.isArray(changedDimensions) && changedDimensions.length > 0
      && changedDimensions.every(dimension => allowedDimensions.has(dimension))
      && requiredDimensions.every(dimension => changedDimensions.includes(dimension)));
  }

  _isBodyProfileCompatible(profile = {}, world = {}) {
    if (!this._hasAuthoredContactAnchors(profile)) return false;
    const heightBand = world?.authoringScalePolicy?.threatRankHeightU?.[profile.visualThreatRank];
    const centerOfMassBand = world?.authoringScalePolicy
      ?.centerOfMassHeightFromGround?.[profile.bodyClass];
    const canonicalHeightU = Number(profile.canonicalHeightU);
    const canonicalWidthU = Number(profile.canonicalWidthU);
    const hasStrictSpatialContract = profile?.spatialContractId === 'actor_spatial_v1';
    if (hasStrictSpatialContract && !this._isActorSpatialContractCompatible(profile)) return false;
    const centerOfMassHeight = hasStrictSpatialContract
      ? Number(profile.centerMassHeightFromGround)
      : 1 - Number(profile.contactAnchors.centerMass.y);
    const outsideBaseline = [];
    if (!(heightBand && canonicalHeightU >= Number(heightBand.min)
      && canonicalHeightU <= Number(heightBand.max))) outsideBaseline.push('canonicalHeightU');
    if (!(centerOfMassBand && centerOfMassHeight >= Number(centerOfMassBand.min)
      && centerOfMassHeight <= Number(centerOfMassBand.max))) outsideBaseline.push('centerMass');
    const authoredOverrideCompatible = outsideBaseline.length > 0
      ? this._isAuthoredScaleOverrideCompatible(profile, world, outsideBaseline)
      : !profile.authoredOverride || this._isAuthoredScaleOverrideCompatible(profile, world);
    // actor_spatial_v1 is an entity-authored contract. Threat rank and body
    // class remain searchable lint metadata, but they must not force a short
    // boss, hovering formation, lanky enemy, or compact player into a global
    // height/COM template. Legacy profiles still use the old bands.
    const authoredEntityDimensionsCompatible = hasStrictSpatialContract
      || Boolean(heightBand && centerOfMassBand && authoredOverrideCompatible);
    return Boolean(authoredEntityDimensionsCompatible
      && Number.isFinite(canonicalHeightU) && canonicalHeightU > 0
      && Number.isFinite(canonicalWidthU) && canonicalWidthU > 0
      && ['feet', 'rooted', 'shadow_projection'].includes(profile.groundingMode)
      && Array.isArray(profile.silhouetteTraits) && profile.silhouetteTraits.length >= 2
      && profile.silhouetteTraits.every(trait => typeof trait === 'string' && trait.trim())
      && typeof profile.threatIntent === 'string' && profile.threatIntent.trim()
      && Math.abs(Number(profile.contactAnchors.ground.y) - 1) <= 0.000001);
  }

  _resolveProfileRenderExtentU(profile = {}, world = {}) {
    const profileId = profile?.id;
    const canonicalHeightU = Number(profile?.canonicalHeightU);
    const canonicalWidthU = Number(profile?.canonicalWidthU);
    if (!profileId || !(canonicalHeightU > 0) || !(canonicalWidthU > 0)) return null;
    let widthU = canonicalWidthU;
    let heightU = canonicalHeightU;
    Object.values(world?.carrierMetrics || {})
      .filter(metric => metric?.bodyProfileId === profileId
        && this._isCarrierMetricCompatible(metric, profile, world))
      .forEach(metric => {
        widthU = Math.max(widthU,
          canonicalWidthU * Number(metric.renderBounds.width) / Number(metric.bodyBounds.width));
        heightU = Math.max(heightU,
          canonicalHeightU * Number(metric.renderBounds.height) / Number(metric.bodyBounds.height));
      });
    Object.entries(world?.actionCarrierMetrics || {})
      .filter(([, metric]) => metric?.bodyProfileId === profileId
        && metric?.bodyBounds?.source === 'verified_mount_metrics_cleaned_actor_carrier'
        && metric?.renderBounds?.source === 'measured_alpha_content')
      .forEach(([metricId, metric]) => {
        const binding = world?.actionScaleBindings?.[metricId];
        const referenceHeight = Number(metric?.referenceHeight);
        const bound = binding?.recordId === metric?.authoredActionScale?.recordId
          && binding?.frameSetId === metricId
          && binding?.bodyProfileId === profileId
          && Number(binding?.referenceHeight) === referenceHeight;
        if (!bound || !(referenceHeight > 0) || !Array.isArray(metric?.renderBounds?.frameRects)) return;
        metric.renderBounds.frameRects.forEach(frame => {
          if (!this._isUnitRect(frame)) return;
          widthU = Math.max(widthU, canonicalHeightU * Number(frame.width) / referenceHeight);
          heightU = Math.max(heightU, canonicalHeightU * Number(frame.height) / referenceHeight);
        });
      });
    return Number.isFinite(widthU) && Number.isFinite(heightU) && widthU > 0 && heightU > 0
      ? { widthU, heightU }
      : null;
  }

  _resolveActorViewportFit(profile = {}, world = {}, mode = 'desktop', viewport = {}, baseHumanHeight = 0, depth = 0) {
    const clamp = profile?.viewportClamp?.[mode];
    const extent = this._resolveProfileRenderExtentU(profile, world);
    const width = Number(viewport?.width);
    const height = Number(viewport?.height);
    const depthEnvelope = profile?.depthEnvelope;
    const perspectiveScale = Math.max(0.85, Math.min(1.15,
      1 + Number(depth) * (Number(world?.layout?.depthProjection?.scalePerDepth) || 0)));
    if (!this._isActorSpatialContractCompatible(profile) || !extent
      || !(width > 0) || !(height > 0)
      || !(Number(baseHumanHeight) > 0)
      || Number(depth) < Number(depthEnvelope?.min) || Number(depth) > Number(depthEnvelope?.max)) return null;
    const nominalBodyHeightPx = Number(baseHumanHeight) * Number(profile.canonicalHeightU) * perspectiveScale;
    const nominalBodyWidthPx = Number(baseHumanHeight) * Number(profile.canonicalWidthU) * perspectiveScale;
    const nominalRenderWidthPx = Number(baseHumanHeight) * extent.widthU * perspectiveScale;
    const nominalRenderHeightPx = Number(baseHumanHeight) * extent.heightU * perspectiveScale;
    const fit = Math.min(1,
      width * Number(clamp.maxRenderedWidthVw) / nominalRenderWidthPx,
      height * Number(clamp.maxRenderedHeightVh) / nominalRenderHeightPx);
    const bodyHeightPx = nominalBodyHeightPx * fit;
    if (!(fit > 0) || bodyHeightPx + 0.000001 < Number(clamp.minReadableHeightPx)) return null;
    return {
      fit,
      perspectiveScale,
      nominalBodyHeightPx,
      nominalBodyWidthPx,
      nominalRenderWidthPx,
      nominalRenderHeightPx,
      bodyHeightPx,
      bodyWidthPx: nominalBodyWidthPx * fit,
      renderWidthPx: nominalRenderWidthPx * fit,
      renderHeightPx: nominalRenderHeightPx * fit,
      extent
    };
  }

  _resolveActionMetricConcurrencyRole(metricId = '') {
    const family = String(metricId).match(/_(attack|skill|guard|victory|reaction|hurt|defeat)(?:_|$)/)?.[1];
    if (['reaction', 'hurt', 'defeat'].includes(family)) return 'response';
    if (['attack', 'skill', 'guard', 'victory'].includes(family)) return 'primary';
    return 'both';
  }

  _resolveActorHorizontalEnvelopes(profile = {}, carrier = {}, world = {}, bodyHeightPx = 0, bodyWidthPx = 0, side = 'player') {
    if (!profile?.id || !(bodyHeightPx > 0) || !(bodyWidthPx > 0)
      || !this._isCarrierMetricCompatible(carrier, profile, world)) return null;
    const canvasScaleX = bodyWidthPx / Number(carrier.bodyBounds.width);
    const canvasScaleY = bodyHeightPx / Number(carrier.bodyBounds.height);
    const staticEnvelope = {
      left: -bodyWidthPx / 2
        + (Number(carrier.renderBounds.x) - Number(carrier.bodyBounds.x)) * canvasScaleX,
      right: -bodyWidthPx / 2
        + (Number(carrier.renderBounds.x) + Number(carrier.renderBounds.width)
          - Number(carrier.bodyBounds.x)) * canvasScaleX,
      top: (Number(carrier.renderBounds.y) - Number(carrier.groundAnchor.y)) * canvasScaleY,
      bottom: (Number(carrier.renderBounds.y) + Number(carrier.renderBounds.height)
        - Number(carrier.groundAnchor.y)) * canvasScaleY
    };
    const envelopes = {
      static: { ...staticEnvelope },
      primary: { ...staticEnvelope },
      response: { ...staticEnvelope },
      all: { ...staticEnvelope }
    };
    let verifiedActionCount = 0;
    const include = (target, left, right, top, bottom) => {
      target.left = Math.min(target.left, left);
      target.right = Math.max(target.right, right);
      target.top = Math.min(target.top, top);
      target.bottom = Math.max(target.bottom, bottom);
    };
    Object.entries(world?.actionCarrierMetrics || {})
      .filter(([, metric]) => metric?.bodyProfileId === profile.id
        && metric?.bodyBounds?.source === 'verified_mount_metrics_cleaned_actor_carrier'
        && metric?.renderBounds?.source === 'measured_alpha_content')
      .forEach(([metricId, metric]) => {
        const binding = world?.actionScaleBindings?.[metricId];
        const referenceHeight = Number(metric.referenceHeight);
        const frames = metric?.renderBounds?.frameRects;
        const roots = metric?.rootAnchor?.framePoints;
        const bound = binding?.recordId === metric?.authoredActionScale?.recordId
          && binding?.frameSetId === metricId
          && binding?.bodyProfileId === profile.id
          && Number(binding?.referenceHeight) === referenceHeight;
        if (!bound || !(referenceHeight > 0) || !Array.isArray(frames) || !Array.isArray(roots)
          || frames.length === 0 || frames.length !== roots.length) return;
        const role = this._resolveActionMetricConcurrencyRole(metricId);
        const targetFacing = side === 'enemy' ? 'left' : 'right';
        const mirrorTowardTarget = ['left', 'right'].includes(metric.authoredFacing)
          && metric.runtimeFacingPolicy === 'toward_primary_target_mirror_carrier_only_when_needed'
          && metric.authoredFacing !== targetFacing;
        const resolvedFrames = [];
        for (let index = 0; index < frames.length; index += 1) {
          const frame = frames[index];
          const root = roots[index];
          if (!this._isUnitRect(frame) || !this._isUnitPoint(root)) return;
          const scale = bodyHeightPx / referenceHeight;
          const authoredLeft = (Number(frame.x) - Number(root.x)) * scale;
          const authoredRight = (Number(frame.x) + Number(frame.width) - Number(root.x)) * scale;
          resolvedFrames.push({
            left: mirrorTowardTarget ? -authoredRight : authoredLeft,
            right: mirrorTowardTarget ? -authoredLeft : authoredRight,
            top: (Number(frame.y) - Number(root.y)) * scale,
            bottom: (Number(frame.y) + Number(frame.height) - Number(root.y)) * scale
          });
        }
        verifiedActionCount += 1;
        resolvedFrames.forEach(frame => {
          include(envelopes.all, frame.left, frame.right, frame.top, frame.bottom);
          if (role === 'both') {
            include(envelopes.primary, frame.left, frame.right, frame.top, frame.bottom);
            include(envelopes.response, frame.left, frame.right, frame.top, frame.bottom);
          } else {
            include(envelopes[role], frame.left, frame.right, frame.top, frame.bottom);
          }
        });
      });
    return verifiedActionCount > 0 ? { ...envelopes, verifiedActionCount } : null;
  }

  _resolveActorExchangeLayout(context = {}, world = {}, sceneContract = null, mode = 'desktop', viewport = {}, portraitSources = {}) {
    if (!sceneContract?.composition?.requiresActorSpatialContract) return null;
    const width = Number(viewport?.width);
    const height = Number(viewport?.height);
    const minimumExchangeGapPx = Number(
      sceneContract.composition?.proportionIntent?.minimumExchangeGapPx?.[mode]
    );
    const authoredPrimaryBodyIntrusion = sceneContract.composition
      ?.proportionIntent?.maximumPrimaryBodyIntrusionPx;
    const intrusionLimit = side => {
      const authored = Number(authoredPrimaryBodyIntrusion?.[side]?.[mode]
        ?? authoredPrimaryBodyIntrusion?.[mode]);
      return Number.isFinite(authored) && authored >= 0 ? authored : null;
    };
    const maximumPrimaryBodyIntrusionPx = {
      player: intrusionLimit('player'),
      enemy: intrusionLimit('enemy')
    };
    if (!(width > 0) || !(height > 0) || !(minimumExchangeGapPx > 0)) return null;
    // Keep the authored 14/28px contract true after CSS sub-pixel rounding and
    // later motion-budget consumption. This is a numerical guard, not a second
    // gameplay gap: callers still receive the authored minimum below.
    const requiredLayoutGapPx = minimumExchangeGapPx + 0.25;
    const uiSafeRect = sceneContract.uiSafeRect;
    const safeBounds = {
      left: width * Number(uiSafeRect?.x),
      right: width * (Number(uiSafeRect?.x) + Number(uiSafeRect?.width)),
      top: height * Number(uiSafeRect?.y),
      bottom: height * (Number(uiSafeRect?.y) + Number(uiSafeRect?.height))
    };
    if (!this._isUnitRect(uiSafeRect) || !(safeBounds.right > safeBounds.left)
      || !(safeBounds.bottom > safeBounds.top)) return null;
    const baseHumanHeight = Math.max(96,
      Number(world?.layout?.baseHumanHeightPx?.[mode]) || (mode === 'narrow' ? 150 : 214));
    const actionAlphaSafeInsetPx = Math.max(0,
      Number(world?.layout?.actionAlphaSafeInsetPx?.[mode]) || 0);
    const inputs = {};
    for (const side of ['player', 'enemy']) {
      const actorCard = context?.actorCards?.[side];
      const placement = sceneContract.composition.actors?.[side];
      const profileId = this._resolvePlacementBodyProfileId(side, placement, context);
      const profile = world?.actorBodyProfiles?.[profileId];
      const carrierResolved = this._resolveActorCarrierMetric(
        actorCard, world, null, portraitSources?.[side] || ''
      );
      if (!profile || !this._isActorSpatialContractCompatible(profile)
        || actorCard?.scaleProfileId !== profileId || !carrierResolved?.metric) return null;
      inputs[side] = {
        side, actorCard, placement, profile,
        carrier: carrierResolved.metric,
        carrierMetricId: carrierResolved.id
      };
    }

    const resolvePairViewportFits = depths => {
      const fits = {};
      for (const side of ['player', 'enemy']) {
        fits[side] = this._resolveActorViewportFit(
          inputs[side].profile, world, mode, { width, height }, baseHumanHeight, depths[side]
        );
        if (!fits[side]) return null;
      }
      // A camera fit is a property of the exchange shot, never of one actor.
      // Use the stricter entity envelope as a single pair-wide camera scale so
      // authored height/width contrast survives narrow screens unchanged.
      return { fits, scale: Math.min(fits.player.fit, fits.enemy.fit) };
    };

    const buildActor = (input, depth, viewportFit, pairViewportScale, layoutScale = 1) => {
      const minimumTotalScale = 1 - Number(input.profile.exchangeFitPolicy.maximumUniformShrinkRatio);
      const minimumLayoutScale = minimumTotalScale / pairViewportScale;
      const minimumReadableHeightPx = Number(input.profile.viewportClamp?.[mode]?.minReadableHeightPx);
      const totalUniformScale = pairViewportScale * layoutScale;
      if (!viewportFit || !(pairViewportScale > 0) || pairViewportScale > 1.000001
        || !(layoutScale > 0) || layoutScale > 1.000001
        || layoutScale + 0.000001 < minimumLayoutScale
        || viewportFit.nominalBodyHeightPx * totalUniformScale + 0.000001 < minimumReadableHeightPx) return null;
      const bodyHeightPx = viewportFit.nominalBodyHeightPx * totalUniformScale;
      const bodyWidthPx = viewportFit.nominalBodyWidthPx * totalUniformScale;
      const envelopes = this._resolveActorHorizontalEnvelopes(
        input.profile, input.carrier, world, bodyHeightPx, bodyWidthPx, input.side
      );
      if (!envelopes) return null;
      const groundY = height * Number(sceneContract.groundY)
        + baseHumanHeight * Number(depth) * (Number(world?.layout?.depthProjection?.groundShiftPerBodyHeight) || 0);
      if (groundY + envelopes.all.top < safeBounds.top - 0.0001
        || groundY + envelopes.all.bottom > safeBounds.bottom + 0.0001) return null;
      return {
        side: input.side,
        profileId: input.profile.id,
        carrierMetricId: input.carrierMetricId,
        authoredHeightRatio: input.profile.authoredHeightRatio,
        authoredWidthRatio: input.profile.authoredWidthRatio,
        centerMassHeightFromGround: input.profile.centerMassHeightFromGround,
        rootMode: input.profile.rootMode,
        threatSources: JSON.parse(JSON.stringify(input.profile.threatSources)),
        preserveThreatAxis: input.profile.viewportClamp.preserveThreatAxis,
        depth,
        layoutScale,
        minimumLayoutScale,
        automaticShrinkRatio: 1 - totalUniformScale,
        viewportScale: pairViewportScale,
        viewportScaleLimit: viewportFit.fit,
        totalUniformScale,
        perspectiveScale: viewportFit.perspectiveScale,
        bodyHeightPx,
        bodyWidthPx,
        renderHeightPx: viewportFit.nominalRenderHeightPx * totalUniformScale,
        renderWidthPx: viewportFit.nominalRenderWidthPx * totalUniformScale,
        groundY,
        envelopes
      };
    };

    const requestedDepths = {
      player: Number(inputs.player.placement.depth),
      enemy: Number(inputs.enemy.placement.depth)
    };
    const buildPair = (depths, scales = { player: 1, enemy: 1 }) => {
      const pairViewport = resolvePairViewportFits(depths);
      if (!pairViewport) return null;
      const player = buildActor(
        inputs.player, depths.player, pairViewport.fits.player, pairViewport.scale, scales.player
      );
      const enemy = buildActor(
        inputs.enemy, depths.enemy, pairViewport.fits.enemy, pairViewport.scale, scales.enemy
      );
      return player && enemy ? { player, enemy } : null;
    };
    // The exchange gap separates the two resting body occupancies.  A sword,
    // fist or spell carrier is expected to enter that space at contact; treating
    // every primary and response export as if all bodies occupied the stage at
    // once forced narrow layouts to dwarf one actor.  Runtime body sequences are
    // serialized below, while every single-action alpha envelope is still kept
    // inside the viewport by playerMin/playerMax and enemyMin/enemyMax.
    const pairGap = actors => actors.enemy.centerX + actors.enemy.envelopes.static.left
      - (actors.player.centerX + actors.player.envelopes.static.right);
    const solveLanes = actors => {
      if (!actors) return null;
      // Passive bodies, labels and readouts stay inside the UI-safe stage.
      // Serialized action reach may use the wider battlefield viewport; trying
      // to reserve both actors' full action envelopes inside the safe rect at
      // once recreates the impossible simultaneous-body fit we removed.
      const playerMin = Math.max(actionAlphaSafeInsetPx - actors.player.envelopes.all.left,
        safeBounds.left - actors.player.envelopes.static.left);
      const playerMax = Math.min(width - actionAlphaSafeInsetPx - actors.player.envelopes.all.right,
        safeBounds.right - actors.player.envelopes.static.right);
      const enemyMin = Math.max(actionAlphaSafeInsetPx - actors.enemy.envelopes.all.left,
        safeBounds.left - actors.enemy.envelopes.static.left);
      const enemyMax = Math.min(width - actionAlphaSafeInsetPx - actors.enemy.envelopes.all.right,
        safeBounds.right - actors.enemy.envelopes.static.right);
      if (playerMin > playerMax + 0.000001 || enemyMin > enemyMax + 0.000001) return null;
      actors.player.centerX = Math.min(playerMax, Math.max(playerMin,
        width * Number(inputs.player.placement.laneX?.[mode])));
      actors.enemy.centerX = Math.min(enemyMax, Math.max(enemyMin,
        width * Number(inputs.enemy.placement.laneX?.[mode])));
      const enemyPrimaryContactGap = () => actors.enemy.centerX + actors.enemy.envelopes.primary.left
        - (actors.player.centerX + actors.player.envelopes.static.right);
      const playerPrimaryContactGap = () => actors.enemy.centerX + actors.enemy.envelopes.static.left
        - (actors.player.centerX + actors.player.envelopes.primary.right);
      let deficit = Math.max(
        0,
        requiredLayoutGapPx - pairGap(actors),
        maximumPrimaryBodyIntrusionPx.enemy === null ? 0
          : -maximumPrimaryBodyIntrusionPx.enemy + 0.25 - enemyPrimaryContactGap(),
        maximumPrimaryBodyIntrusionPx.player === null ? 0
          : -maximumPrimaryBodyIntrusionPx.player + 0.25 - playerPrimaryContactGap()
      );
      const playerAvailable = Math.max(0, actors.player.centerX - playerMin);
      const enemyAvailable = Math.max(0, enemyMax - actors.enemy.centerX);
      const playerFirstShift = Math.min(playerAvailable, deficit / 2);
      actors.player.centerX -= playerFirstShift;
      deficit -= playerFirstShift;
      const enemyShift = Math.min(enemyAvailable, deficit);
      actors.enemy.centerX += enemyShift;
      deficit -= enemyShift;
      const playerSecondShift = Math.min(Math.max(0, actors.player.centerX - playerMin), deficit);
      actors.player.centerX -= playerSecondShift;
      deficit -= playerSecondShift;
      if (deficit > 0.0001 || pairGap(actors) + 0.0001 < requiredLayoutGapPx
        || (maximumPrimaryBodyIntrusionPx.enemy !== null
          && enemyPrimaryContactGap() < -maximumPrimaryBodyIntrusionPx.enemy - 0.0001)
        || (maximumPrimaryBodyIntrusionPx.player !== null
          && playerPrimaryContactGap() < -maximumPrimaryBodyIntrusionPx.player - 0.0001)) return null;
      actors.player.laneShiftPx = actors.player.centerX
        - width * Number(inputs.player.placement.laneX?.[mode]);
      actors.enemy.laneShiftPx = actors.enemy.centerX
        - width * Number(inputs.enemy.placement.laneX?.[mode]);
      return actors;
    };

    const resolutionTrace = ['lane_shift'];
    let resolvedDepths = { ...requestedDepths };
    let resolved = solveLanes(buildPair(resolvedDepths));
    if (!resolved) {
      resolutionTrace.push('depth_envelope');
      resolvedDepths.player = Number(inputs.player.profile.depthEnvelope.min);
      resolved = solveLanes(buildPair(resolvedDepths));
      if (!resolved) {
        resolvedDepths.enemy = Number(inputs.enemy.profile.depthEnvelope.min);
        resolved = solveLanes(buildPair(resolvedDepths));
      }
    }
    if (!resolved) {
      // Shrinking one side changes the authored threat relationship and used
      // to make the player the automatic sacrifice. If the authored camera and
      // depth lanes still need relief, scale the pair uniformly so every
      // entity keeps its independently authored height/width contrast.
      resolutionTrace.push('pair_uniform_scale_preserve_authored_ratio');
      const resolveUniformPairScale = () => {
        // A pair scale is legal only when it is above both the authored shrink
        // allowance and the measured readable-body floor for each entity. The
        // old cap-only floor could be *below* minReadableHeightPx; probing that
        // invalid endpoint made the monotonic solver return null even though a
        // slightly larger, fully valid shared scale existed.
        const pairViewport = resolvePairViewportFits(resolvedDepths);
        if (!pairViewport) return null;
        const floor = Math.max(...['player', 'enemy'].map(side => {
          const input = inputs[side];
          const viewportFit = pairViewport.fits[side];
          if (!viewportFit?.nominalBodyHeightPx) return Number.POSITIVE_INFINITY;
          const shrinkFloor = (1
            - Number(input.profile.exchangeFitPolicy.maximumUniformShrinkRatio)) / pairViewport.scale;
          const readableFloor = Number(input.profile.viewportClamp?.[mode]?.minReadableHeightPx)
            / (viewportFit.nominalBodyHeightPx * pairViewport.scale);
          return Math.max(shrinkFloor, readableFloor);
        }));
        if (!(floor > 0) || floor > 1.000001) return null;
        let best = solveLanes(buildPair(resolvedDepths, { player: floor, enemy: floor }));
        if (!best) return null;
        let passing = floor;
        let failing = 1;
        for (let iteration = 0; iteration < 32; iteration += 1) {
          const candidateScale = (passing + failing) / 2;
          const scales = { player: candidateScale, enemy: candidateScale };
          const candidate = solveLanes(buildPair(resolvedDepths, scales));
          if (candidate) {
            passing = candidateScale;
            best = candidate;
          } else {
            failing = candidateScale;
          }
        }
        return best;
      };
      resolved = resolveUniformPairScale();
    }
    if (!resolved) return null;

    const resolvedGap = pairGap(resolved);
    const resolvedEnemyPrimaryBodyIntrusionPx = Math.max(0,
      resolved.player.centerX + resolved.player.envelopes.static.right
        - (resolved.enemy.centerX + resolved.enemy.envelopes.primary.left));
    const resolvedPlayerPrimaryBodyIntrusionPx = Math.max(0,
      resolved.player.centerX + resolved.player.envelopes.primary.right
        - (resolved.enemy.centerX + resolved.enemy.envelopes.static.left));
    // Motion is bounded by the active source's own verified alpha extent.  The
    // opposing actor remains in its authored depth lane and provides the contact
    // target; weapon/reach overlap is interaction, not body-scale authority.
    const playerViewportAdvance = Math.max(0,
      width - actionAlphaSafeInsetPx
        - (resolved.player.centerX + resolved.player.envelopes.primary.right));
    const playerExchangeAdvance = Math.max(0,
      resolved.enemy.centerX + resolved.enemy.envelopes.response.left
        - (resolved.player.centerX + resolved.player.envelopes.primary.right)
        - minimumExchangeGapPx);
    const enemyViewportAdvance = Math.max(0,
      resolved.enemy.centerX + resolved.enemy.envelopes.primary.left - actionAlphaSafeInsetPx);
    const enemyExchangeAdvance = Math.max(0,
      resolved.enemy.centerX + resolved.enemy.envelopes.primary.left
        - (resolved.player.centerX + resolved.player.envelopes.response.right)
        - minimumExchangeGapPx);
    const playerAdvance = Math.min(playerViewportAdvance, playerExchangeAdvance);
    const enemyAdvance = Math.min(enemyViewportAdvance, enemyExchangeAdvance);
    resolved.player.motionEnvelope = {
      contractId: 'actor_motion_envelope_v1', viewportMode: mode,
      maxAdvanceTowardPx: playerAdvance,
      maxRetreatAwayPx: Math.max(0,
        resolved.player.centerX + resolved.player.envelopes.all.left - actionAlphaSafeInsetPx)
    };
    resolved.enemy.motionEnvelope = {
      contractId: 'actor_motion_envelope_v1', viewportMode: mode,
      maxAdvanceTowardPx: enemyAdvance,
      maxRetreatAwayPx: Math.max(0, width - actionAlphaSafeInsetPx
        - (resolved.enemy.centerX + resolved.enemy.envelopes.all.right))
    };
    return {
      contractId: 'actor_exchange_layout_v1',
      viewportMode: mode,
      viewport: { width, height },
      actionAlphaSafeInsetPx,
      minimumExchangeGapPx,
      resolvedExchangeGapPx: resolvedGap,
      maximumPrimaryBodyIntrusionPx,
      resolvedPrimaryBodyIntrusionPx: {
        player: resolvedPlayerPrimaryBodyIntrusionPx,
        enemy: resolvedEnemyPrimaryBodyIntrusionPx
      },
      uiSafeBounds: safeBounds,
      concurrencyPolicy: {
        id: 'serialized_active_body_v1',
        exchangeGapEnvelope: 'static',
        activeEnvelope: 'primary',
        passiveEnvelope: 'static',
        responseScheduling: 'after_active_body_sequence'
      },
      resolutionTrace,
      actors: resolved
    };
  }

  _isCarrierMetricCompatible(metric = {}, profile = null, world = null) {
    const body = metric?.bodyBounds;
    const render = metric?.renderBounds;
    const resolvedWorld = world || this._currentContext?.visualWorld || null;
    const scaleBindings = resolvedWorld?.carrierScaleBindings;
    const scaleRecord = scaleBindings?.[metric?.assetSha256];
    const authoredScale = metric?.authoredScale;
    const near = (left, right, tolerance = 0.000001) => Number.isFinite(Number(left))
      && Number.isFinite(Number(right)) && Math.abs(Number(left) - Number(right)) <= tolerance;
    const bodyAspect = Number(body?.width) / Number(body?.height);
    const profileAspect = Number(profile?.canonicalWidthU) / Number(profile?.canonicalHeightU);
    const strictProfileBindingCompatible = profile?.spatialContractId !== 'actor_spatial_v1'
      || (scaleRecord?.bodyProfileContractSha256 === profile?.bodyProfileContractSha256
        && ['speciesId', 'morphologyId', 'progressionStageId', 'combatRoleId'].every(field => (
          scaleRecord?.authoredScaleBasis?.[field] === profile?.authoredScaleBasis?.[field]
        )));
    const authoredScaleCompatible = Boolean(profile
      && authoredScale?.source === 'external_carrier_scale_provenance_v1'
      && authoredScale.assetSha256 === metric?.assetSha256
      && scaleRecord?.recordId === authoredScale.recordId
      && scaleRecord.assetSha256 === metric?.assetSha256
      && this._normaliseVisualAssetPath(scaleRecord.assetPath)
        === this._normaliseVisualAssetPath(metric?.assetPath)
      && scaleRecord.bodyProfileId === metric?.bodyProfileId
      && scaleRecord.bodyProfileId === profile?.id
      && near(scaleRecord.canonicalHeightU, profile?.canonicalHeightU)
      && near(scaleRecord.canonicalWidthU, profile?.canonicalWidthU)
      && scaleRecord.bodyClass === profile?.bodyClass
      && scaleRecord.visualThreatRank === profile?.visualThreatRank
      && near(scaleRecord.naturalWidth, metric?.naturalWidth)
      && near(scaleRecord.naturalHeight, metric?.naturalHeight)
      && ['x', 'y', 'width', 'height'].every(key => near(scaleRecord.bodyBounds?.[key], body?.[key]))
      && ['x', 'y', 'width', 'height', 'feetY'].every(key => near(scaleRecord.renderBounds?.[key], render?.[key]))
      && scaleRecord.groundAnchor?.mode === metric?.groundAnchor?.mode
      && ['x', 'y'].every(key => near(scaleRecord.groundAnchor?.[key], metric?.groundAnchor?.[key]))
      && near(scaleRecord.bodyBoundsAspect, bodyAspect)
      && near(bodyAspect, profileAspect)
      && strictProfileBindingCompatible);
    const groundingMode = metric?.groundAnchor?.mode;
    const groundingCompatible = groundingMode === 'feet'
      ? Math.abs(Number(metric?.groundAnchor?.y) - Number(render?.feetY)) <= 0.000001
        && (!profile || profile.groundingMode === 'feet')
      : groundingMode === 'rooted'
        ? Math.abs(Number(metric?.groundAnchor?.y) - Number(render?.feetY)) <= 0.000001
          && (!profile || profile.groundingMode === 'rooted')
      : groundingMode === 'shadow_projection'
        && Number(metric?.groundAnchor?.y) >= Number(render?.feetY)
        && (!profile || profile.groundingMode === 'shadow_projection');
    return Boolean(this._isUnitRect(body)
      && this._isUnitRect(render)
      && this._isUnitNumber(render.feetY)
      && this._isUnitPoint(metric?.groundAnchor)
      && metric.bodyBoundsPolicy === 'authored_anatomy_excludes_weapon_vfx'
      && metric.renderBoundsPolicy === 'measured_alpha_content'
      && Number(metric.naturalWidth) > 0
      && Number(metric.naturalHeight) > 0
      && body.x >= render.x - 0.000001
      && body.y >= render.y - 0.000001
      && body.x + body.width <= render.x + render.width + 0.000001
      && body.y + body.height <= render.y + render.height + 0.000001
      && groundingCompatible
      && authoredScaleCompatible);
  }

  _resolveWorldComposition(context = {}, world = {}, mode = 'desktop') {
    const battlefieldProfileId = String(context?.battlefieldProfileId || '');
    const encounterCompositionId = String(context?.encounterCompositionId || '');
    const battlefield = world?.battlefieldProfiles?.[battlefieldProfileId];
    const composition = world?.encounterCompositions?.[encounterCompositionId];
    const horizonY = battlefield?.horizonY?.[mode];
    const groundY = battlefield?.groundY?.[mode];
    const crop = battlefield?.crop?.[mode];
    const uiSafeRect = battlefield?.uiSafeRect?.[mode];
    const mediaContract = world?.mediaDensityContract;
    const mediaCompatible = Boolean(mediaContract
      && battlefield?.mediaDensity === mediaContract.mediaDensity
      && Number(battlefield?.logicalPixelGrid) === Number(mediaContract.logicalPixelGrid)
      && Array.isArray(battlefield?.compatibleWorldIds)
      && battlefield.compatibleWorldIds.includes(world?.id)
      && Array.isArray(mediaContract?.runtimeEligibleReviewStatuses)
      && mediaContract.runtimeEligibleReviewStatuses.includes(battlefield?.mediaReviewStatus)
      && !mediaContract?.forbiddenMediaDensity?.includes(battlefield?.mediaDensity));
    const depthProjection = world?.layout?.depthProjection;
    const zOffsets = depthProjection?.zIndexOffsets;
    const depthContractCompatible = Number(depthProjection?.groundShiftPerBodyHeight) > 0
      && Number(depthProjection?.scalePerDepth) > 0
      && Number(depthProjection?.zDepthThresholds?.farMax) < 0
      && Number(depthProjection?.zDepthThresholds?.nearMin) > 0
      && Number.isInteger(zOffsets?.far) && Number.isInteger(zOffsets?.mid) && Number.isInteger(zOffsets?.near)
      && zOffsets.far >= 0 && zOffsets.far < zOffsets.mid && zOffsets.mid < zOffsets.near
      && Number(world?.layerTokens?.actors) + zOffsets.near < Number(world?.layerTokens?.labels);
    const resolvedActorProfiles = {};
    const requiresActorSpatialContract = composition?.requiresActorSpatialContract === true;
    const actorsCompatible = ['player', 'enemy'].every(side => {
      const placement = composition?.actors?.[side];
      const depth = placement?.depth;
      const laneX = placement?.laneX?.[mode];
      const expectedBodyProfileId = this._resolvePlacementBodyProfileId(side, placement, context);
      const profile = world?.actorBodyProfiles?.[expectedBodyProfileId];
      const depthEnvelope = profile?.depthEnvelope;
      resolvedActorProfiles[side] = { id: expectedBodyProfileId, profile };
      return expectedBodyProfileId === context?.actorCards?.[side]?.scaleProfileId
        && this._isBodyProfileCompatible(profile, world)
        && (!requiresActorSpatialContract || this._isActorSpatialContractCompatible(profile))
        && typeof depth === 'number' && Number.isFinite(depth) && depth >= -1 && depth <= 1
        && (!requiresActorSpatialContract
          || (depth >= Number(depthEnvelope?.min) && depth <= Number(depthEnvelope?.max)))
        && typeof laneX === 'number' && laneX > 0 && laneX < 1;
    });
    const proportionIntent = composition?.proportionIntent;
    const proportionContractCompatible = !requiresActorSpatialContract
      || (proportionIntent?.scaleContrastPolicy === 'derive_from_resolved_body_profiles'
        && typeof proportionIntent?.preserveThreatAxis === 'string'
        && proportionIntent.preserveThreatAxis.trim()
        && Number(proportionIntent?.minimumExchangeGapPx?.narrow) > 0
        && Number(proportionIntent?.minimumExchangeGapPx?.desktop) > 0);
    const compoundRequirement = composition?.requiresCompoundActor;
    const requiredCompoundProfile = compoundRequirement?.side
      ? resolvedActorProfiles[compoundRequirement.side]?.profile : null;
    const compoundContractCompatible = !compoundRequirement || Boolean(
      ['player', 'enemy'].includes(compoundRequirement.side)
      && compoundRequirement.contractId === 'compound_actor_formation_v1'
      && requiredCompoundProfile?.compoundActor?.contractId === compoundRequirement.contractId
      && requiredCompoundProfile.compoundActor.mode === 'single_combat_entity'
      && Number.isInteger(requiredCompoundProfile.compoundActor.memberCount)
      && requiredCompoundProfile.compoundActor.memberCount > 1
    );
    if (!battlefield || battlefield.id !== battlefieldProfileId
      || this._normaliseVisualAssetPath(battlefield.sceneImage) !== this._normaliseVisualAssetPath(context.sceneImage)
      || !composition || composition.id !== encounterCompositionId
      || composition.battlefieldProfileId !== battlefieldProfileId
      || !(horizonY > 0 && horizonY < groundY && groundY < 1)
      || crop?.fit !== 'cover'
      || !this._isUnitNumber(crop.focusX) || !this._isUnitNumber(crop.focusY)
      || !this._isUnitRect(uiSafeRect)
      || !mediaCompatible
      || !depthContractCompatible
      || !actorsCompatible
      || !proportionContractCompatible
      || !compoundContractCompatible) return null;
    const playerProfile = resolvedActorProfiles.player?.profile;
    const enemyProfile = resolvedActorProfiles.enemy?.profile;
    const resolvedScaleContrast = {
      playerProfileId: resolvedActorProfiles.player?.id,
      enemyProfileId: resolvedActorProfiles.enemy?.id,
      heightRatio: Number(enemyProfile.canonicalHeightU) / Number(playerProfile.canonicalHeightU),
      widthRatio: Number(enemyProfile.canonicalWidthU) / Number(playerProfile.canonicalWidthU),
      policy: requiresActorSpatialContract
        ? proportionIntent.scaleContrastPolicy
        : 'legacy_authored_profiles'
    };
    return {
      battlefieldProfileId,
      encounterCompositionId,
      battlefield,
      composition,
      crop,
      uiSafeRect,
      horizonY,
      groundY,
      resolvedScaleContrast
    };
  }

  _resolvePlacementBodyProfileId(side, placement = {}, context = {}) {
    if (side !== 'player') return placement?.bodyProfileId || null;
    if (placement?.profileBinding === 'runtime_player_actor_card') {
      const runtimeProfileId = typeof context?.actorCards?.player?.scaleProfileId === 'string'
        ? context.actorCards.player.scaleProfileId.trim()
        : '';
      return runtimeProfileId || null;
    }
    const byPath = placement?.bodyProfileIdsByPath;
    if (!byPath || typeof byPath !== 'object' || Array.isArray(byPath)) {
      return placement?.bodyProfileId || null;
    }
    const pathId = String(context?.playerPath || this._currentContext?.playerPath || '');
    return typeof byPath[pathId] === 'string' && byPath[pathId] ? byPath[pathId] : null;
  }

  _resolveActorCarrierMetric(actorCard = {}, world = {}, portrait = null, preferredSource = '') {
    const bodyProfileId = actorCard?.scaleProfileId;
    const profile = world?.actorBodyProfiles?.[bodyProfileId];
    if (!profile || !this._isBodyProfileCompatible(profile, world)) return null;
    const metrics = world.carrierMetrics || {};
    const authoredSources = [preferredSource, actorCard.image]
      .map(source => this._normaliseVisualAssetPath(source)).filter(Boolean);
    const sourceCandidates = [
      preferredSource,
      portrait?.currentSrc,
      portrait?.getAttribute?.('src'),
      actorCard.image
    ].map(source => this._normaliseVisualAssetPath(source)).filter(Boolean);
    for (const source of sourceCandidates) {
      const match = Object.entries(metrics).find(([, metric]) => this._normaliseVisualAssetPath(metric?.assetPath) === source
        && metric?.bodyProfileId === bodyProfileId
        && this._isCarrierMetricCompatible(metric, profile, world));
      if (match) return { id: match[0], metric: match[1], source };
    }
    if (authoredSources.length > 0) return null;
    const fallback = metrics[profile.defaultCarrierMetricId];
    return fallback?.bodyProfileId === bodyProfileId && this._isCarrierMetricCompatible(fallback, profile, world)
      ? { id: profile.defaultCarrierMetricId, metric: fallback, source: this._normaliseVisualAssetPath(fallback.assetPath) }
      : null;
  }

  _applyActorWorldComposition(side, actorCard = {}, world = {}, mode = 'desktop', viewport = {}, portraitSource = '', sceneContract = null, exchangeLayout = null) {
    const area = side === 'enemy' ? this.enemyContainer : this.playerContainer;
    const card = side === 'enemy' ? this.enemyActorCard : this.playerActorCard;
    const sprite = side === 'enemy' ? this.enemySprite : this.playerSprite;
    const portrait = side === 'enemy' ? this.enemyPortrait : this.playerPortrait;
    const scaleProfileId = typeof actorCard?.scaleProfileId === 'string' ? actorCard.scaleProfileId : '';
    const profile = world?.actorBodyProfiles?.[scaleProfileId];
    const placement = sceneContract?.composition?.actors?.[side];
    const expectedBodyProfileId = this._resolvePlacementBodyProfileId(side, placement, this._currentContext || {});
    const carrier = this._resolveActorCarrierMetric(actorCard, world, portrait, portraitSource);
    if (!area || !card || !sprite || !portrait || !profile || !carrier?.metric
      || expectedBodyProfileId !== scaleProfileId) {
      this._clearActorWorldComposition(side);
      if (card) card.dataset.worldScaleStatus = 'missing-profile';
      return false;
    }

    const layout = world.layout || {};
    const width = Math.max(320, Number(viewport.width) || 0);
    const height = Math.max(568, Number(viewport.height) || 0);
    const baseHumanHeight = Math.max(96, Number(layout.baseHumanHeightPx?.[mode]) || (mode === 'narrow' ? 150 : 214));
    const canonicalHeightU = Math.max(0.45, Number(profile.canonicalHeightU) || 1);
    const canonicalWidthU = Math.max(0.1, Number(profile.canonicalWidthU) || 0);
    const bodyBounds = carrier.metric.bodyBounds;
    const renderBounds = carrier.metric.renderBounds;
    const groundAnchor = carrier.metric.groundAnchor;
    const hasStrictSpatialContract = profile.spatialContractId === 'actor_spatial_v1';
    const actorLayoutPlan = exchangeLayout?.contractId === 'actor_exchange_layout_v1'
      ? exchangeLayout?.actors?.[side]
      : null;
    const strictLayoutCompatible = Boolean(actorLayoutPlan
      && actorLayoutPlan.profileId === scaleProfileId
      && actorLayoutPlan.carrierMetricId === carrier.id
      && actorLayoutPlan.motionEnvelope?.contractId === 'actor_motion_envelope_v1'
      && Number(actorLayoutPlan.authoredHeightRatio) === Number(profile.authoredHeightRatio)
      && Number(actorLayoutPlan.authoredWidthRatio) === Number(profile.authoredWidthRatio));
    if (hasStrictSpatialContract && !strictLayoutCompatible) {
      this._clearActorWorldComposition(side);
      card.dataset.worldScaleStatus = 'invalid-exchange-layout-contract';
      return false;
    }
    const depth = hasStrictSpatialContract ? Number(actorLayoutPlan.depth) : Number(placement.depth);
    const perspectiveScale = actorLayoutPlan?.perspectiveScale || Math.max(0.85, Math.min(1.15,
      1 + depth * (Number(layout.depthProjection?.scalePerDepth) || 0)));
    let bodyHeight = actorLayoutPlan?.bodyHeightPx || baseHumanHeight * canonicalHeightU * perspectiveScale;
    let bodyWidth = actorLayoutPlan?.bodyWidthPx || baseHumanHeight * canonicalWidthU * perspectiveScale;
    if (!hasStrictSpatialContract) {
      const maximumBodyWidth = width * (mode === 'narrow' ? 0.78 : 0.48);
      if (bodyWidth > maximumBodyWidth) {
        const fit = maximumBodyWidth / bodyWidth;
        bodyWidth *= fit;
        bodyHeight *= fit;
      }
    }

    const laneX = Number(placement.laneX?.[mode]);
    const requestedCenterX = width * laneX;
    const canvasScaleX = bodyWidth / Number(bodyBounds.width);
    const renderLeftFromBody = (Number(renderBounds.x) - Number(bodyBounds.x)) * canvasScaleX;
    const renderRightFromBody = (Number(renderBounds.x) + Number(renderBounds.width) - Number(bodyBounds.x)) * canvasScaleX;
    const staticLeftOffset = -bodyWidth / 2 + renderLeftFromBody;
    const staticRightOffset = -bodyWidth / 2 + renderRightFromBody;
    let authoredLeftOffset = actorLayoutPlan?.envelopes?.all?.left ?? staticLeftOffset;
    let authoredRightOffset = actorLayoutPlan?.envelopes?.all?.right ?? staticRightOffset;
    if (!hasStrictSpatialContract) {
      Object.values(world.actionCarrierMetrics || {})
        .filter(metric => metric?.bodyProfileId === scaleProfileId
          && metric?.bodyBounds?.source === 'verified_mount_metrics_cleaned_actor_carrier')
        .forEach(metric => {
          const referenceHeight = Number(metric.referenceHeight);
          const roots = metric.rootAnchor?.framePoints;
          const frames = metric.renderBounds?.frameRects;
          if (!(referenceHeight > 0) || !Array.isArray(roots) || !Array.isArray(frames)
            || roots.length !== frames.length) return;
          const actionCanvasScale = bodyHeight / referenceHeight;
          frames.forEach((frame, index) => {
            const root = roots[index];
            if (!this._isUnitRect(frame) || !this._isUnitPoint(root)) return;
            authoredLeftOffset = Math.min(authoredLeftOffset,
              (Number(frame.x) - Number(root.x)) * actionCanvasScale);
            authoredRightOffset = Math.max(authoredRightOffset,
              (Number(frame.x) + Number(frame.width) - Number(root.x)) * actionCanvasScale);
          });
        });
    }
    const minimumCenterX = 6 - authoredLeftOffset;
    const maximumCenterX = width - 6 - authoredRightOffset;
    const centerX = hasStrictSpatialContract
      ? Number(actorLayoutPlan.centerX)
      : Math.min(maximumCenterX, Math.max(minimumCenterX, requestedCenterX));
    const groundY = height * sceneContract.groundY
      + baseHumanHeight * depth * (Number(layout.depthProjection?.groundShiftPerBodyHeight) || 0);
    const left = centerX - bodyWidth / 2;
    const top = groundY - bodyHeight;

    const canvasHeightPercent = 100 / Number(bodyBounds.height);
    const canvasWidthPercent = 100 / Number(bodyBounds.width);
    const canvasBottomPercent = -((1 - Number(groundAnchor.y)) / Number(bodyBounds.height)) * 100;
    const canvasHeightPx = bodyHeight / Number(bodyBounds.height);
    const canvasBottomPx = -((1 - Number(groundAnchor.y)) / Number(bodyBounds.height)) * bodyHeight;
    const renderTopY = groundY + canvasBottomPx
      - canvasHeightPx + Number(renderBounds.y) * canvasHeightPx;
    const kickerTop = renderTopY - top - (mode === 'narrow' ? 17 : 19);
    const bodyCenterX = Number(bodyBounds.x) + Number(bodyBounds.width) / 2;
    const canvasXBiasPercent = -((bodyCenterX - 0.5) / Number(bodyBounds.width)) * 100;
    const authoredShadow = profile.shadowFootprintU;
    const shadowFootprint = {
      width: Number(authoredShadow?.width) > 0
        ? Number(authoredShadow.width)
        : canonicalWidthU * 0.78,
      height: Number(authoredShadow?.height) > 0
        ? Number(authoredShadow.height)
        : Math.max(0.045, canonicalHeightU * 0.065)
    };
    const resolvedWorldUnitPx = bodyHeight / canonicalHeightU;
    const shadowWidth = Math.max(6, Number(shadowFootprint?.width) * resolvedWorldUnitPx);
    const shadowHeight = Math.max(3, Number(shadowFootprint?.height) * resolvedWorldUnitPx);
    const shadowBottom = profile.groundingMode === 'shadow_projection'
      ? -shadowHeight * 0.46
      : -shadowHeight * 0.34;

    area.style.setProperty('--actor-center-x', `${centerX.toFixed(2)}px`);
    area.style.setProperty('--actor-ground-y', `${groundY.toFixed(2)}px`);
    card.style.setProperty('--actor-left', `${left.toFixed(2)}px`);
    card.style.setProperty('--actor-top', `${top.toFixed(2)}px`);
    card.style.setProperty('--actor-body-width', `${bodyWidth.toFixed(2)}px`);
    card.style.setProperty('--actor-body-height', `${bodyHeight.toFixed(2)}px`);
    card.style.setProperty('--actor-canvas-height', `${canvasHeightPercent.toFixed(3)}%`);
    card.style.setProperty('--actor-canvas-width', `${canvasWidthPercent.toFixed(3)}%`);
    card.style.setProperty('--actor-canvas-bottom', `${canvasBottomPercent.toFixed(3)}%`);
    card.style.setProperty('--actor-canvas-x-bias', `${canvasXBiasPercent.toFixed(3)}%`);
    card.style.setProperty('--actor-action-canvas-height', `${canvasHeightPercent.toFixed(3)}%`);
    card.style.setProperty('--actor-action-canvas-width', `${canvasWidthPercent.toFixed(3)}%`);
    card.style.setProperty('--actor-action-canvas-bottom', `${canvasBottomPercent.toFixed(3)}%`);
    card.style.setProperty('--actor-kicker-top', `${kickerTop.toFixed(2)}px`);
    card.style.setProperty('--actor-shadow-width', `${shadowWidth.toFixed(2)}px`);
    card.style.setProperty('--actor-shadow-height', `${shadowHeight.toFixed(2)}px`);
    card.style.setProperty('--actor-shadow-bottom', `${shadowBottom.toFixed(2)}px`);
    card.dataset.scaleProfileId = scaleProfileId;
    card.dataset.massClass = profile.massClass || 'unknown';
    card.dataset.canonicalHeightU = String(canonicalHeightU);
    card.dataset.canonicalWidthU = String(canonicalWidthU);
    card.dataset.authoredHeightRatio = String(profile.authoredHeightRatio ?? canonicalHeightU);
    card.dataset.authoredWidthRatio = String(profile.authoredWidthRatio ?? canonicalWidthU);
    card.dataset.centerMassHeightFromGround = String(profile.centerMassHeightFromGround ?? '');
    card.dataset.rootMode = String(profile.rootMode || 'legacy');
    card.dataset.spatialContractId = String(profile.spatialContractId || 'legacy');
    card.dataset.authoredScaleBasis = JSON.stringify(profile.authoredScaleBasis || null);
    card.dataset.bodyProfileContractSha256 = String(profile.bodyProfileContractSha256 || '');
    card.dataset.compoundActor = JSON.stringify(profile.compoundActor || null);
    card.dataset.viewportClampStatus = hasStrictSpatialContract ? 'resolved' : 'legacy';
    if (actorLayoutPlan) {
      card.dataset.viewportFit = String(actorLayoutPlan.viewportScale);
      card.dataset.exchangeLayoutScale = String(actorLayoutPlan.layoutScale);
      card.dataset.totalUniformScale = String(actorLayoutPlan.totalUniformScale);
      card.dataset.maximumUniformShrinkRatio = String(profile.exchangeFitPolicy.maximumUniformShrinkRatio);
      card.dataset.maxRenderExtentU = JSON.stringify(actorLayoutPlan.envelopes.all);
      card.dataset.exchangeEnvelope = JSON.stringify(actorLayoutPlan.envelopes);
      card.dataset.motionEnvelope = JSON.stringify(actorLayoutPlan.motionEnvelope);
      card.dataset.exchangeChoreographyPolicyId = String(exchangeLayout?.concurrencyPolicy?.id || '');
      card.dataset.resolvedActorCenterX = actorLayoutPlan.centerX.toFixed(2);
      card.dataset.resolvedRenderWidthPx = actorLayoutPlan.renderWidthPx.toFixed(2);
      card.dataset.resolvedRenderHeightPx = actorLayoutPlan.renderHeightPx.toFixed(2);
      card.dataset.resolvedBodyWidthPx = actorLayoutPlan.bodyWidthPx.toFixed(2);
      card.dataset.resolvedBodyHeightPx = actorLayoutPlan.bodyHeightPx.toFixed(2);
    }
    card.dataset.bodyClass = String(profile.bodyClass);
    card.dataset.visualThreatRank = String(profile.visualThreatRank);
    card.dataset.groundingMode = String(profile.groundingMode);
    card.dataset.shadowFootprintU = JSON.stringify(shadowFootprint);
    card.dataset.resolvedShadowWidthPx = shadowWidth.toFixed(2);
    card.dataset.resolvedShadowHeightPx = shadowHeight.toFixed(2);
    card.dataset.silhouetteTraits = JSON.stringify(profile.silhouetteTraits);
    card.dataset.worldGroundY = groundY.toFixed(2);
    card.dataset.worldDepth = String(depth);
    card.dataset.carrierMetricId = carrier.id;
    card.dataset.carrierAssetPath = carrier.source;
    card.dataset.bodyBounds = JSON.stringify(bodyBounds);
    card.dataset.renderBounds = JSON.stringify(renderBounds);
    card.dataset.groundAnchor = JSON.stringify(groundAnchor);
    card.dataset.contactAnchorStatus = 'resolved';
    card.dataset.encounterCompositionId = sceneContract.encounterCompositionId;
    card.dataset.worldScaleStatus = 'resolved';
    sprite.dataset.scaleProfileId = scaleProfileId;
    sprite.dataset.visualWorldId = world.id || '';
    area.dataset.visualWorldId = world.id || '';
    area.dataset.worldLayer = 'actors';
    const farMax = Number(layout.depthProjection?.zDepthThresholds?.farMax);
    const nearMin = Number(layout.depthProjection?.zDepthThresholds?.nearMin);
    const zOffsets = layout.depthProjection?.zIndexOffsets || {};
    const zBand = depth <= farMax ? 'far' : depth >= nearMin ? 'near' : 'mid';
    const actorZIndex = Number(world.layerTokens?.actors) + Number(zOffsets[zBand]);
    area.style.setProperty('--actor-z-index', String(actorZIndex));
    area.dataset.worldDepthBand = zBand;
    const stageContractResolved = this.stagePresenter?.setActorWorldContract?.(side, {
      bodyProfileId: scaleProfileId,
      canonicalHeightU,
      canonicalWidthU,
      authoredHeightRatio: profile.authoredHeightRatio,
      authoredWidthRatio: profile.authoredWidthRatio,
      centerMassHeightFromGround: profile.centerMassHeightFromGround,
      bodyClass: profile.bodyClass,
      visualThreatRank: profile.visualThreatRank,
      groundingMode: profile.groundingMode,
      shadowFootprintU: profile.shadowFootprintU,
      rootMode: profile.rootMode,
      depthEnvelope: profile.depthEnvelope,
      viewportClamp: profile.viewportClamp,
      threatSources: profile.threatSources,
      authoredScaleBasis: profile.authoredScaleBasis,
      bodyProfileContractSha256: profile.bodyProfileContractSha256,
      compoundActor: profile.compoundActor,
      hoverContract: profile.hoverContract,
      exchangeFitPolicy: profile.exchangeFitPolicy,
      spatialContractId: profile.spatialContractId,
      silhouetteTraits: profile.silhouetteTraits,
      bodyBounds,
      renderBounds,
      bodyBoundsPolicy: carrier.metric.bodyBoundsPolicy,
      renderBoundsPolicy: carrier.metric.renderBoundsPolicy,
      groundAnchor,
      contactAnchors: profile.contactAnchors,
      battlefieldProfileId: sceneContract.battlefieldProfileId,
      encounterCompositionId: sceneContract.encounterCompositionId,
      depth,
      exchangeLayoutContractId: exchangeLayout?.contractId,
      minimumExchangeGapPx: exchangeLayout?.minimumExchangeGapPx,
      resolvedExchangeGapPx: exchangeLayout?.resolvedExchangeGapPx,
      layoutScale: actorLayoutPlan?.layoutScale,
      motionEnvelope: actorLayoutPlan?.motionEnvelope
    });
    if (stageContractResolved !== true) {
      this._clearActorWorldComposition(side);
      card.dataset.worldScaleStatus = 'missing-stage-contract';
      return false;
    }
    return true;
  }

  _applyVisualWorldContext(context = {}, intent = null) {
    if (!this.container) return false;
    const world = context?.visualWorld;
    const width = typeof window !== 'undefined' ? window.innerWidth : this.container.clientWidth;
    const height = typeof window !== 'undefined' ? window.innerHeight : this.container.clientHeight;
    const mode = width <= 720 ? 'narrow' : 'desktop';
    const requestedCompatible = context?.visualWorldCompatible === true && world?.id === context?.visualWorldId;
    const sceneContract = requestedCompatible ? this._resolveWorldComposition(context, world, mode) : null;
    const compatible = Boolean(sceneContract);
    this.container.dataset.visualWorldCompatible = compatible ? 'true' : 'false';
    this.container.dataset.visualWorldId = compatible ? world.id : 'legacy_unreviewed';
    this.container.dataset.worldReviewStatus = compatible ? String(world.reviewStatus || 'candidate') : 'unreviewed';
    this.container.dataset.worldUiMaterial = compatible ? String(world.uiMaterial?.id || '') : '';
    this.container.dataset.worldVfxRenderer = compatible ? String(world.vfxPolicy?.rendererAuthority || '') : '';
    this.container.dataset.worldMediaDensity = compatible ? String(world.mediaDensityContract?.mediaDensity || '') : '';
    this.container.dataset.worldLogicalPixelGrid = compatible ? String(world.mediaDensityContract?.logicalPixelGrid || '') : '';
    this.container.dataset.worldUiMediaDensity = compatible ? String(world.uiMaterial?.mediaDensity || '') : '';
    this.container.dataset.worldUiLogicalPixelGrid = compatible ? String(world.uiMaterial?.logicalPixelGrid || '') : '';
    this.container.dataset.worldUiReviewStatus = compatible ? String(world.uiMaterial?.reviewStatus || '') : '';
    this.container.dataset.worldUiFinalArtApproved = compatible && world.uiMaterial?.finalArtApproved === true ? 'true' : 'false';
    this.container.dataset.worldMaterialSurfaceCount = compatible
      ? String(Object.keys(world.uiMaterial?.surfaces || {}).length)
      : '0';
    this.container.dataset.worldVfxAssetCount = compatible ? String(Object.keys(world.vfxAssets || {}).length) : '0';
    this.container.dataset.worldLightingId = compatible ? String(world.lighting?.runtimeComposite?.id || '') : '';
    this.container.dataset.contactShadowRenderer = compatible ? String(world.contactShadow?.renderMode || '') : '';
    this.container.dataset.contactShadowMediaDensity = compatible ? String(world.contactShadow?.mediaDensity || '') : '';
    this.container.dataset.contactShadowLogicalPixelGrid = compatible
      ? String(world.contactShadow?.logicalPixelGrid || '')
      : '';
    this.container.dataset.contactShadowReviewStatus = compatible ? String(world.contactShadow?.reviewStatus || '') : '';
    if (typeof document !== 'undefined') {
      document.documentElement.dataset.combatAmbientGlow = compatible && world.vfxPolicy?.ambientGlowForbidden === true
        ? 'forbidden'
        : 'allowed';
    }
    const worldSurfaces = [
      [this.atmosphere, 'background'],
      [this.exchangeStage, 'exchange'],
      [this.playerContainer, 'actors'],
      [this.enemyContainer, 'actors'],
      [this.handContainer, 'ui']
    ];
    worldSurfaces.forEach(([surface, layer]) => {
      if (!surface) return;
      surface.dataset.visualWorldId = compatible ? world.id : 'legacy_unreviewed';
      surface.dataset.worldLayer = layer;
    });
    if (!compatible) {
      this._clearVisualWorldProperties();
      this._clearActorWorldComposition('player');
      this._clearActorWorldComposition('enemy');
      this.container.dataset.worldScaleResolved = 'false';
      delete this.container.dataset.battlefieldProfileId;
      delete this.container.dataset.encounterCompositionId;
      return false;
    }

    const ambient = Array.isArray(world.palette?.ambient) ? world.palette.ambient : [];
    this.container.dataset.worldViewportMode = mode;
    this.container.dataset.battlefieldProfileId = sceneContract.battlefieldProfileId;
    this.container.dataset.encounterCompositionId = sceneContract.encounterCompositionId;
    this.container.dataset.resolvedPlayerScaleProfileId = sceneContract.resolvedScaleContrast.playerProfileId;
    this.container.dataset.resolvedEnemyScaleProfileId = sceneContract.resolvedScaleContrast.enemyProfileId;
    this.container.dataset.resolvedActorHeightRatio = String(sceneContract.resolvedScaleContrast.heightRatio);
    this.container.dataset.resolvedActorWidthRatio = String(sceneContract.resolvedScaleContrast.widthRatio);
    this.container.dataset.resolvedScaleContrastPolicy = sceneContract.resolvedScaleContrast.policy;
    this.container.style.setProperty('--world-ink', ambient[0] || '#0d0b0a');
    this.container.style.setProperty('--world-ink-soft', ambient[1] || '#2b333d');
    this.container.style.setProperty('--world-mid', ambient[2] || '#3d4a5c');
    this.container.style.setProperty('--world-paper-dim', ambient[3] || '#8a9aa8');
    this.container.style.setProperty('--world-paper', ambient[4] || '#e8e0cc');
    this.container.style.setProperty('--world-impact', world.palette?.functional?.impact || '#d7dac0');
    this.container.style.setProperty('--world-cinnabar', world.palette?.functional?.danger || '#a65345');
    this.container.style.setProperty('--world-intent', world.palette?.functional?.enemyIntent || '#c8a965');
    this.container.style.setProperty('--world-actor-lighting-filter', world.lighting.runtimeComposite.actorFilter);
    this.container.style.setProperty('--world-contact-shadow-color', world.contactShadow.color);
    Object.values(world.uiMaterial.surfaces).forEach(surface => {
      const runtimeSurfacePath = `/${this._normaliseVisualAssetPath(surface.path)}`;
      this.container.style.setProperty(surface.cssVariable, `url("${runtimeSurfacePath}")`);
      surface.consumerSelectors
        .filter(selector => typeof selector === 'string' && selector && !selector.includes('::'))
        .forEach(selector => {
          this.container.querySelectorAll(selector).forEach(element => {
            element.dataset.worldUiSurfaceId = surface.id;
            element.dataset.mediaDensity = surface.mediaDensity;
            element.dataset.logicalPixelGrid = String(surface.logicalPixelGrid);
            element.dataset.mediaReviewStatus = surface.reviewStatus;
          });
        });
    });
    this.container.style.setProperty('--world-horizon-y', `${(sceneContract.horizonY * 100).toFixed(3)}%`);
    this.container.style.setProperty('--world-ground-y', `${(sceneContract.groundY * 100).toFixed(3)}%`);
    this.container.style.setProperty('--world-battlefield-focus-x', `${(sceneContract.crop.focusX * 100).toFixed(3)}%`);
    this.container.style.setProperty('--world-battlefield-focus-y', `${(sceneContract.crop.focusY * 100).toFixed(3)}%`);
    this.container.style.setProperty('--world-battlefield-zoom', String(Math.max(1, Number(sceneContract.crop.zoom) || 1)));
    this.container.style.setProperty('--world-ui-safe-x', `${(sceneContract.uiSafeRect.x * 100).toFixed(3)}%`);
    this.container.style.setProperty('--world-ui-safe-y', `${(sceneContract.uiSafeRect.y * 100).toFixed(3)}%`);
    this.container.style.setProperty('--world-ui-safe-width', `${(sceneContract.uiSafeRect.width * 100).toFixed(3)}%`);
    this.container.style.setProperty('--world-ui-safe-height', `${(sceneContract.uiSafeRect.height * 100).toFixed(3)}%`);
    Object.entries(world.layerTokens || {}).forEach(([layer, value]) => {
      if (Number.isInteger(value)) this.container.style.setProperty(`--combat-layer-${layer}`, String(value));
    });
    if (this.atmosphere) {
      this.atmosphere.dataset.battlefieldProfileId = sceneContract.battlefieldProfileId;
      this.atmosphere.dataset.cropPolicy = sceneContract.crop.fit;
      this.atmosphere.dataset.mediaDensity = sceneContract.battlefield.mediaDensity;
      this.atmosphere.dataset.logicalPixelGrid = String(sceneContract.battlefield.logicalPixelGrid);
      this.atmosphere.dataset.mediaReviewStatus = sceneContract.battlefield.mediaReviewStatus;
    }
    const playerPortraitSource = this._resolveActorPortraitSource('player', context?.actorCards?.player, intent);
    const enemyPortraitSource = this._resolveActorPortraitSource('enemy', context?.actorCards?.enemy, intent);
    const exchangeLayout = sceneContract.composition.requiresActorSpatialContract
      ? this._resolveActorExchangeLayout(
        context, world, sceneContract, mode, { width, height },
        { player: playerPortraitSource, enemy: enemyPortraitSource }
      )
      : null;
    if (sceneContract.composition.requiresActorSpatialContract && !exchangeLayout) {
      this._clearActorWorldComposition('player');
      this._clearActorWorldComposition('enemy');
      this.container.dataset.worldScaleResolved = 'false';
      return false;
    }
    if (exchangeLayout) {
      this.container.dataset.exchangeLayoutContractId = exchangeLayout.contractId;
      this.container.dataset.minimumExchangeGapPx = String(exchangeLayout.minimumExchangeGapPx);
      this.container.dataset.resolvedExchangeGapPx = String(exchangeLayout.resolvedExchangeGapPx);
      this.container.dataset.maximumPrimaryBodyIntrusionPx = JSON.stringify(exchangeLayout.maximumPrimaryBodyIntrusionPx);
      this.container.dataset.resolvedPrimaryBodyIntrusionPx = JSON.stringify(exchangeLayout.resolvedPrimaryBodyIntrusionPx);
      this.container.dataset.exchangeLayoutResolutionTrace = JSON.stringify(exchangeLayout.resolutionTrace);
      this.container.dataset.exchangeChoreographyPolicyId = String(exchangeLayout.concurrencyPolicy?.id || '');
    }
    const playerResolved = this._applyActorWorldComposition('player', context?.actorCards?.player, world, mode, { width, height }, playerPortraitSource, sceneContract, exchangeLayout);
    const enemyResolved = this._applyActorWorldComposition('enemy', context?.actorCards?.enemy, world, mode, { width, height }, enemyPortraitSource, sceneContract, exchangeLayout);
    this.container.dataset.worldScaleResolved = playerResolved && enemyResolved ? 'true' : 'false';
    return playerResolved && enemyResolved;
  }

  _setActorPortrait(sprite, imageElement, portrait, altText, assetId = '') {
    if (!sprite) return;
    const source = typeof portrait === 'string' ? portrait.trim() : '';
    // A decoded <img> is the only portrait surface.  Mirroring the enemy
    // image into the sprite background made an opaque rectangular card behind
    // the actor, even when the surrounding combatant marker was transparent.
    const useCompositorFallback = false;
    sprite.dataset.assetId = assetId || '';
    if (!imageElement) {
      sprite.dataset.pendingPortrait = source;
      sprite.classList.remove('has-image');
      sprite.style.backgroundImage = source ? `url('${source}')` : '';
      sprite.classList.toggle('has-image', Boolean(source));
      return;
    }
    const currentSource = imageElement.getAttribute('src') || '';
    imageElement.alt = source ? altText : '';
    if (source
      && currentSource === source
      && sprite.dataset.portraitReady === source
      && imageElement.naturalWidth > 0) {
      sprite.style.backgroundImage = useCompositorFallback ? `url('${source}')` : '';
      imageElement.hidden = false;
      sprite.classList.add('has-image');
      return;
    }
    if (source
      && currentSource === source
      && sprite.dataset.pendingPortrait === source
      && sprite.dataset.portraitReady !== source) {
      return;
    }
    const requestId = String((Number(sprite.dataset.portraitRequest) || 0) + 1);
    sprite.dataset.portraitRequest = requestId;
    sprite.dataset.pendingPortrait = source;
    sprite.dataset.portraitReady = '';
    sprite.classList.remove('has-image');
    sprite.style.backgroundImage = '';
    imageElement.hidden = true;
    if (!source) {
      imageElement.removeAttribute('src');
      return;
    }
    const revealDecodedPortrait = () => {
      if (sprite.dataset.portraitRequest !== requestId
        || sprite.dataset.pendingPortrait !== source
        || imageElement.getAttribute('src') !== source
        || imageElement.naturalWidth <= 0) return;
      const reveal = () => {
        if (sprite.dataset.portraitRequest !== requestId
          || sprite.dataset.pendingPortrait !== source
          || imageElement.getAttribute('src') !== source) return;
        sprite.dataset.portraitReady = source;
        sprite.style.backgroundImage = useCompositorFallback ? `url('${source}')` : '';
        imageElement.hidden = false;
        sprite.classList.add('has-image');
        if (this._currentContext?.visualWorldCompatible) {
          this._applyVisualWorldContext(this._currentContext, this._currentIntent);
        }
      };
      if (typeof imageElement.decode === 'function') {
        imageElement.decode().then(reveal).catch(reveal);
      } else {
        reveal();
      }
    };
    imageElement.onload = revealDecodedPortrait;
    imageElement.onerror = () => {
      if (sprite.dataset.portraitRequest !== requestId
        || sprite.dataset.pendingPortrait !== source) return;
      sprite.dataset.pendingPortrait = '';
      sprite.dataset.portraitReady = '';
      sprite.style.backgroundImage = '';
      imageElement.hidden = true;
      sprite.classList.remove('has-image');
    };
    if (imageElement.getAttribute('src') !== source) imageElement.src = source;
    if (imageElement.complete) revealDecodedPortrait();
  }

  _getVisualWorldRequestState(context = {}) {
    const requestedVisualWorldId = context?.requestedVisualWorldId
      || context?.visualWorldIncompatibility?.encounterVisualWorldId
      || context?.visualWorldId
      || context?.visualWorld?.id
      || null;
    const requested = Boolean(requestedVisualWorldId);
    const resolved = Boolean(
      requested
      && context?.visualWorldCompatible === true
      && context?.visualWorld?.id === context?.visualWorldId
      && context?.visualWorldId === requestedVisualWorldId
    );
    return { requested, resolved, requestedVisualWorldId };
  }

  _setScene(context, intent = null) {
    const previousCardId = this._currentContext?.cardId || null;
    const nextCardId = context?.cardId || null;
    const sceneChanged = Boolean(previousCardId && previousCardId !== nextCardId);
    if (sceneChanged) {
      this._clearBossPhasePresentations({ resetSeen: true });
      this._seenVfxEventIds.clear();
    }
    this._currentContext = context || {};
    this._currentIntent = intent;
    const visualWorldResolved = this._applyVisualWorldContext(this._currentContext, intent);
    const reviewedWorldRequested = this._getVisualWorldRequestState(context).requested;
    const requestedMediaAllowed = visualWorldResolved || !reviewedWorldRequested;
    const retainMissingScene = requestedMediaAllowed && !sceneChanged;
    if (this.container) this.container.dataset.requestedMediaAllowed = requestedMediaAllowed ? 'true' : 'false';
    if (requestedMediaAllowed) {
      this._preloadSemanticActionFrames(context?.actionAnimations);
      this._preloadBossPhaseTransitionFrames(context?.bossPhaseTransition);
    }
    const image = context && context.sceneImage;
    const enemyActor = context?.actorCards?.enemy;
    // Enemy intentions are a playable telegraph, not a late-loading portrait.
    // Preload the complete authored set as the combat scene opens so changing
    // from debuff to strike/guard never leaves an empty actor bay between turns.
    if (requestedMediaAllowed) {
      this._preloadActorPortraitFrames(enemyActor);
      this._preloadActorPortraitFrames(context?.actorCards?.player);
    }
      this._setBattlefieldImage(requestedMediaAllowed ? image : null, { retainOnMissing: retainMissingScene });
      if (this.enemySprite) {
        const portrait = requestedMediaAllowed
          ? (this._resolveActorPortraitSource('enemy', enemyActor, intent)
            || (context && context.enemyImage))
          : null;
        this._setActorPortrait(
          this.enemySprite,
          this.enemyPortrait,
          portrait,
          `${enemyActor?.name || context?.enemyType || '敌手'}战斗立绘`,
          enemyActor?.id || ''
        );
      }
    if (this.enemyKicker) {
      this.enemyKicker.textContent = context?.enemyType || enemyActor?.kicker || '敌手';
    }
      if (this.playerSprite) {
        const playerActor = context?.actorCards?.player;
        const portrait = requestedMediaAllowed ? playerActor?.image : null;
        this._setActorPortrait(
          this.playerSprite,
          this.playerPortrait,
          portrait,
          `${playerActor?.name || '一念修者'}战斗立绘`,
          playerActor?.id || ''
        );
        if (this.playerName) this.playerName.textContent = playerActor?.name || '一念修者';
      if (this.playerKicker) this.playerKicker.textContent = playerActor?.kicker || '行者';
      if (this.qiLabel) this.qiLabel.textContent = context?.uiTheme?.resourceLabel || '真元';
    }
    const treasure = Array.isArray(context?.equippedTreasures) ? context.equippedTreasures[0] : null;
    if (this.playerTreasure) {
      this.playerTreasure.hidden = !treasure;
      this.playerTreasure.dataset.treasureId = treasure?.treasureId || '';
      this.playerTreasure.dataset.assetId = treasure?.cardArt?.id || '';
      this.playerTreasure.setAttribute('aria-expanded', 'false');
    }
    if (this.playerTreasureArt) {
      this.playerTreasureArt.src = treasure?.cardArt?.image || '';
      this.playerTreasureArt.alt = treasure ? `${treasure.name}法宝卡面` : '';
    }
    if (this.playerTreasureName) this.playerTreasureName.textContent = treasure?.name || '';
    if (this.playerTreasureSummary) this.playerTreasureSummary.textContent = treasure?.summary || '';
    this._renderCombatDossierDock(context);
    if (!treasure && !(context?.companionContracts || []).length) {
      this._closeTreasureInspector({ restoreFocus: false });
    }
    if (this.container) {
      this.container.dataset.presentationId = context?.presentationId || '';
      this.container.dataset.battlefieldId = context?.battlefieldId || '';
      this.container.dataset.playerPath = context?.playerPath || '';
      this.container.dataset.uiThemeId = context?.uiTheme?.id || '';
      this.container.dataset.protagonistIdentityId = context?.protagonistIdentityId || '';
      this.container.dataset.requestedVisualStageId = context?.requestedVisualStageId || '';
      this.container.dataset.displayedVisualStageId = context?.displayedVisualStageId || '';
      this.container.dataset.visualStageFallback = context?.visualStageFallback ? 'true' : 'false';
      this.container.dataset.visualStageAssetStatus = context?.visualStageAssetStatus || '';
    }
  }

  _openTreasureInspector() {
    this._openCombatDossier('treasure', 0, this.playerTreasure);
  }

  _getCombatDossierItems(kind) {
    if (kind === 'companion') {
      return Array.isArray(this._currentContext?.companionContracts)
        ? this._currentContext.companionContracts
        : [];
    }
    return Array.isArray(this._currentContext?.equippedTreasures)
      ? this._currentContext.equippedTreasures
      : [];
  }

  _renderCombatDossierDock(context) {
    const companions = Array.isArray(context?.companionContracts) ? context.companionContracts : [];
    const treasures = Array.isArray(context?.equippedTreasures) ? context.equippedTreasures : [];
    if (this.companionCount) this.companionCount.textContent = String(companions.length);
    if (this.treasureCount) this.treasureCount.textContent = String(treasures.length);
    if (this.dossierDock) {
      this.dossierDock.hidden = companions.length === 0 && treasures.length === 0;
      this.dossierDock.dataset.companionCount = String(companions.length);
      this.dossierDock.dataset.treasureCount = String(treasures.length);
    }

    const buildButton = (item, kind, index) => {
      const button = document.createElement('button');
      const isCompanion = kind === 'companion';
      const stableId = isCompanion ? item.compId : item.treasureId;
      const asset = item.cardArt || {};
      button.type = 'button';
      button.className = `combat-dossier-avatar dossier-${kind}`;
      button.dataset.dossierKind = kind;
      button.dataset.dossierIndex = String(index);
      button.dataset.assetId = asset.id || '';
      if (isCompanion) {
        button.dataset.companionId = stableId || '';
      } else {
        button.dataset.treasureId = stableId || '';
      }
      button.setAttribute('aria-label', `查看${isCompanion ? '道侣' : '法宝'}卡：${item.companionName || item.name || stableId}`);

      if (asset.image) {
        const image = document.createElement('img');
        image.src = asset.image;
        image.alt = '';
        image.draggable = false;
        button.appendChild(image);
      } else {
        const sigil = document.createElement('span');
        sigil.className = 'combat-dossier-sigil';
        sigil.textContent = String(item.companionName || item.name || '藏').slice(0, 1);
        button.appendChild(sigil);
      }
      const label = document.createElement('span');
      label.className = 'combat-dossier-avatar-label';
      label.textContent = item.companionName || item.name || stableId || '未命名';
      button.appendChild(label);
      button.addEventListener('click', () => this._openCombatDossier(kind, index, button));
      return button;
    };

    if (this.companionRoster) {
      const nodes = companions.length
        ? companions.map((item, index) => buildButton(item, 'companion', index))
        : [this._buildDossierEmptyState('尚未缔结可参战羁绊')];
      this.companionRoster.replaceChildren(...nodes);
    }
    if (this.treasureRoster) {
      const nodes = treasures.length
        ? treasures.map((item, index) => buildButton(item, 'treasure', index))
        : [this._buildDossierEmptyState('当前没有已装备法宝')];
      this.treasureRoster.replaceChildren(...nodes);
    }
  }

  _buildDossierEmptyState(text) {
    const empty = document.createElement('span');
    empty.className = 'combat-dossier-empty';
    empty.textContent = text;
    return empty;
  }

  _openCombatDossier(kind, index, opener = null) {
    const items = this._getCombatDossierItems(kind);
    if (!items.length || !this.treasureInspector) return;
    const safeIndex = ((Number(index) || 0) % items.length + items.length) % items.length;
    const item = items[safeIndex];
    const isCompanion = kind === 'companion';
    this._dossierKind = kind;
    this._dossierIndex = safeIndex;
    if (opener) this._dossierOpener = opener;

    const slotNames = {
      weapon: '兵刃槽',
      armor: '护体槽',
      accessory: '佩饰槽',
      artifact: '法宝槽'
    };
    const cardId = isCompanion ? item.cardId : item.tacticalCardId;
    const cardDef = typeof deckCombatSystem !== 'undefined' ? deckCombatSystem.cardDB?.[cardId] : null;
    const provenance = this._currentContext?.cardProvenance?.[cardId] || {};
    const asset = DeckCombatUI.resolveCombatDossierAsset(kind, item);
    const usesObjectArt = !isCompanion && asset === item.objectArt;
    const rarity = Number(item.rarity) || 1;
    const bonuses = item.combatBonuses || {};
    const facts = isCompanion
      ? [
          `当前好感 ${Number(item.affection) || 0}`,
          `本阶门槛 ${Number(item.minAffection) || 0}`,
          item.tierId === 'bond_100' ? '天命羁绊' : '道侣羁绊',
          `稳定 ID · ${item.compId}`
        ]
      : [
          slotNames[item.slot] || item.slot || '器物槽',
          `品阶 ${'◆'.repeat(Math.max(1, Math.min(5, rarity)))}`,
          `稳定 ID · ${item.treasureId}`
        ];
    if (!isCompanion && Number(bonuses.atk)) facts.push(`攻击 +${Number(bonuses.atk)}`);
    if (!isCompanion && Number(bonuses.def)) facts.push(`防御 +${Number(bonuses.def)}`);
    if (!isCompanion && Number(bonuses.critRate)) facts.push(`会心 +${Number(bonuses.critRate)}%`);

    if (this.treasureInspectorArt) {
      this.treasureInspectorArt.src = asset.image || '';
      this.treasureInspectorArt.alt = isCompanion
        ? `${item.companionName || item.name || '道侣'}完整卡面`
        : `${item.name || '法宝'}实体立绘`;
    }
    if (this.treasureInspectorEyebrow) {
      this.treasureInspectorEyebrow.textContent = isCompanion
        ? `${item.tierId === 'bond_100' ? '天命羁绊' : '道侣战契'} · 已并肩`
        : `${slotNames[item.slot] || '器物槽'} · 已装备`;
    }
    if (this.treasureInspectorName) {
      this.treasureInspectorName.textContent = item.companionName || item.name || item.compId || item.treasureId;
    }
    if (this.treasureInspectorId) this.treasureInspectorId.textContent = asset.id || cardId || item.compId || item.treasureId;
    if (this.treasureInspectorSummary) {
      this.treasureInspectorSummary.textContent = isCompanion
        ? (item.mechanism || provenance.description || '羁绊气机已与角色相连。')
        : (item.summary || '器物气机已与角色相连。');
    }
    if (this.treasureInspectorFacts) {
      this.treasureInspectorFacts.replaceChildren(...facts.map(value => {
        const chip = document.createElement('span');
        chip.textContent = value;
        return chip;
      }));
    }
    if (this.treasureInspectorCard) {
      this.treasureInspectorCard.textContent = isCompanion
        ? (cardDef?.name
          || provenance.displayName
          || item.unlockText
          || cardId
          || '并肩战契')
        : (item.displayName
          || provenance.displayName
          || cardDef?.name
          || cardId
          || '被动器契');
    }
    if (this.treasureInspectorTrigger) {
      if (isCompanion) {
        this.treasureInspectorTrigger.textContent = cardDef?.description
          ? `${cardDef.description} 好感达到 ${Number(item.minAffection) || 0} 后自动加入本场牌库。`
          : `好感达到 ${Number(item.minAffection) || 0} 后自动加入本场牌库。`;
      } else {
        const triggerName = item.trigger === 'onCardPlay'
          ? `打出${item.triggerCardType ? `【${item.triggerCardType}】` : ''}卡牌时共鸣`
          : (item.trigger || '装备后持续生效');
        this.treasureInspectorTrigger.textContent = item.cardDescription
          ? `${item.cardDescription}；${triggerName}。`
          : `${triggerName}。`;
      }
    }
    if (this.dossierMechanismLabel) this.dossierMechanismLabel.textContent = isCompanion ? '羁绊技能' : '器契机制';
    if (this.dossierCounter) this.dossierCounter.textContent = `${safeIndex + 1} / ${items.length}`;
    if (this.dossierPrev) this.dossierPrev.disabled = items.length < 2;
    if (this.dossierNext) this.dossierNext.disabled = items.length < 2;

    this.treasureInspector.dataset.dossierKind = kind;
    this.treasureInspector.dataset.objectArt = String(usesObjectArt);
    this.treasureInspector.dataset.materialTone = usesObjectArt ? (asset.materialTone || '') : '';
    this.treasureInspector.dataset.stableId = isCompanion ? (item.compId || '') : (item.treasureId || '');
    this.treasureInspector.dataset.assetId = asset.id || '';
    this.treasureInspector.hidden = false;
    if (!isCompanion) this.playerTreasure?.setAttribute('aria-expanded', 'true');
    document.body.classList.add('combat-inspector-open');
    requestAnimationFrame(() => this.treasureInspector.classList.add('is-open'));
    this.treasureInspectorClose?.focus();
  }

  _stepCombatDossier(direction) {
    const items = this._getCombatDossierItems(this._dossierKind);
    if (items.length < 2) return;
    this._openCombatDossier(this._dossierKind, this._dossierIndex + Number(direction || 0));
  }

  _closeTreasureInspector({ restoreFocus = true } = {}) {
    if (!this.treasureInspector || this.treasureInspector.hidden) return;
    this.treasureInspector.classList.remove('is-open');
    this.treasureInspector.hidden = true;
    this.playerTreasure?.setAttribute('aria-expanded', 'false');
    document.body.classList.remove('combat-inspector-open');
    if (restoreFocus) {
      const focusTarget = this._dossierOpener?.isConnected
        ? this._dossierOpener
        : (this.playerTreasure && !this.playerTreasure.hidden ? this.playerTreasure : null);
      focusTarget?.focus();
    }
    this._dossierOpener = null;
  }

  playCardCommit(data) {
    if (!data || !this.container) return;
    this.container.dataset.lastCommittedCard = data.cardId || '';
    this.container.dataset.lastCommittedArtId = data.artId || '';
    // The entry banner has served its purpose once the player commits a real
    // technique. Keeping it over the stage would make the next action read as
    // a stack of UI cards instead of a moment in the battlefield.
    this.entryBanner?.classList.remove('visible');
    const actor = data.target === 'player' ? this.enemyContainer : this.playerContainer;
    if (actor) {
      actor.classList.remove('actor-committed');
      void actor.offsetWidth;
      actor.classList.add('actor-committed');
      this._reflowPathSynergyCues();
      setTimeout(() => { actor.classList.remove('actor-committed'); this._reflowPathSynergyCues(); }, this._reducedMotion ? 20 : 420);
    }
    if (!this.actionLayer || !data.artImage) return;
    const echo = document.createElement('div');
    // A committed card is a momentary scene cue, not a second full-size card.
    // The hand remains the only card-shaped control; the stage reserves its
    // visual priority for the acting character and the battlefield.
    // A committed card is a short-lived notation for the action already
    // accepted by DeckCombatSystem.  It is intentionally not a second large
    // card floating over the actor or battlefield.
    echo.className = 'combat-card-echo combat-technique-notation';
    echo.dataset.combatSurface = 'action-notation';
    echo.dataset.artId = data.artId || '';
    echo.dataset.cardType = data.cardType || 'skill';
    const image = document.createElement('img');
    image.src = data.artImage;
    image.alt = '';
    image.draggable = false;
    const label = document.createElement('span');
    label.className = 'combat-card-echo-label';
    const kicker = document.createElement('small');
    kicker.textContent = '出手';
    const title = document.createElement('strong');
    title.textContent = data.cardName || '已出牌';
    label.append(kicker, title);
    echo.append(image, label);
    this.actionLayer.replaceChildren(echo);
    requestAnimationFrame(() => echo.classList.add('visible'));
    setTimeout(() => {
      echo.classList.remove('visible');
      setTimeout(() => echo.remove(), this._reducedMotion ? 10 : 220);
    }, this._reducedMotion ? 80 : 430);
  }

  _setBattlefieldImage(image, { retainOnMissing = true } = {}) {
    if (!this.atmosphere) return;
    const fallback = 'linear-gradient(145deg, #364552 0%, #202d38 48%, #453129 100%)';
    const source = typeof image === 'string' && image.trim() ? image.trim() : null;
    if (!source) {
      // Resume renders can briefly arrive without presentation context after a
      // fully authored combat render. Retain the last battlefield instead of
      // replacing it with an empty dark surface between those two updates.
      if (retainOnMissing && this._sceneImageSource) return;
      this._sceneImageSource = null;
      this._sceneLoadToken += 1;
      this.atmosphere.dataset.sceneSource = '';
      this.atmosphere.dataset.sceneState = 'fallback';
      this.atmosphere.style.backgroundImage = fallback;
      this.container?.style?.setProperty('--world-battlefield-root-image', fallback);
      return;
    }
    const renderedSource = this.atmosphere.dataset.sceneSource || '';
    const renderedState = this.atmosphere.dataset.sceneState || '';
    const rootBackgroundSource = (() => {
      try { return new URL(source, window.location.href).href; } catch (_error) { return source; }
    })();
    if (renderedSource === source && (renderedState === 'ready' || renderedState === 'loading')) {
      this._sceneImageSource = source;
      this.container?.style?.setProperty('--world-battlefield-root-image',
        renderedState === 'ready' ? `url('${rootBackgroundSource}')` : fallback);
      return;
    }
    this._sceneImageSource = source;
    const token = ++this._sceneLoadToken;
    // A CSS background URL can exist while the compositor still paints the
    // root fallback. Keep a deliberate mid-tone stage visible until this exact
    // source has decoded; do not briefly show a black void after resume.
    this.atmosphere.dataset.sceneSource = source;
    this.atmosphere.dataset.sceneState = 'loading';
    this.atmosphere.style.backgroundImage = fallback;
    this.container?.style?.setProperty('--world-battlefield-root-image', fallback);
    const preload = new Image();
    const commit = () => {
      if (token !== this._sceneLoadToken || this._sceneImageSource !== source) return;
      this.atmosphere.style.backgroundImage = `url('${source}')`;
      this.container?.style?.setProperty('--world-battlefield-root-image', `url('${rootBackgroundSource}')`);
      this.atmosphere.dataset.sceneState = 'ready';
    };
    preload.addEventListener('load', () => {
      const decoded = typeof preload.decode === 'function' ? preload.decode() : Promise.resolve();
      Promise.resolve(decoded).catch(() => undefined).then(commit);
    }, { once: true });
    preload.addEventListener('error', () => {
      if (token !== this._sceneLoadToken || this._sceneImageSource !== source) return;
      this.atmosphere.dataset.sceneState = 'fallback';
    }, { once: true });
    preload.src = source;
  }

  playStoryAssist(data) {
    if (!data || !this.container) return;
    this.container.dataset.lastStoryAssistId = data.assistId || '';
    this.container.dataset.lastStoryAssistCompanion = data.companionId || '';
    const companionButton = this.companionRoster
      ? [...this.companionRoster.querySelectorAll('[data-companion-id]')]
        .find(node => node.dataset.companionId === String(data.companionId || ''))
      : null;
    if (companionButton) {
      companionButton.classList.remove('is-assisting');
      void companionButton.offsetWidth;
      companionButton.classList.add('is-assisting');
      setTimeout(() => companionButton.classList.remove('is-assisting'), this._reducedMotion ? 80 : 900);
    }
    const cue = document.createElement('div');
    cue.className = 'combat-story-assist-cue';
    cue.dataset.assistId = data.assistId || '';
    const kicker = document.createElement('small');
    kicker.textContent = '同行者援护';
    const title = document.createElement('strong');
    title.textContent = `${data.companionName || '同行者'} · ${data.cardName || '援护'}`;
    const mechanism = document.createElement('span');
    mechanism.textContent = data.mechanism || '与玩家的本次出牌共同结算';
    cue.append(kicker, title, mechanism);
    (this.actionLayer || this.container).appendChild(cue);
    requestAnimationFrame(() => cue.classList.add('visible'));
    setTimeout(() => {
      cue.classList.remove('visible');
      setTimeout(() => cue.remove(), this._reducedMotion ? 10 : 240);
    }, this._reducedMotion ? 320 : 1300);
  }

  playTreasureTrigger(data) {
    if (!data || !this.container) return;
    this.container.dataset.lastTreasureId = data.treasureId || '';
    this.container.dataset.lastTreasureFxId = data.assetId || '';
    if (this.playerTreasure) {
      this.playerTreasure.classList.remove('is-triggered');
      void this.playerTreasure.offsetWidth;
      this.playerTreasure.classList.add('is-triggered');
      setTimeout(() => this.playerTreasure?.classList.remove('is-triggered'), this._reducedMotion ? 40 : 560);
    }
  }

  _vibrate(pattern) {
    if (this._reducedMotion || typeof navigator === 'undefined' || typeof navigator.vibrate !== 'function') return;
    navigator.vibrate(pattern);
  }

  playAnim(data) {
      let targetEl;
      if (data.target === 'player') {
          targetEl = document.querySelector('.player-area');
      } else if (data.target === 'enemy') {
          targetEl = document.querySelector('.enemy-area');
      }

      if (!targetEl) return;

      if (data.type === 'shake') {
          targetEl.classList.remove('shake');
          void targetEl.offsetWidth; // trigger reflow
           targetEl.classList.add('shake');
          if (data.target === 'player') this._vibrate(28);
      } else if (data.type === 'floating_text') {
          const viewModel = DeckCombatUI.buildCombatFeedbackViewModel(data);
          const floater = document.createElement('div');
          const lane = targetEl.querySelectorAll('.combat-feedback-burst').length % 3;
          floater.className = `floating-text combat-feedback-burst feedback-${viewModel.tone}`;
          floater.style.setProperty('--feedback-lane', String(lane));

          const sigil = document.createElement('span');
          sigil.className = 'combat-feedback-sigil';
          sigil.textContent = viewModel.sigil;
          const copy = document.createElement('span');
          copy.className = 'combat-feedback-copy';
          const headline = document.createElement('strong');
          headline.textContent = `${viewModel.label}${viewModel.valueText ? ` ${viewModel.valueText}` : ''}`;
          const caption = document.createElement('small');
          caption.textContent = viewModel.caption;
          copy.append(headline, caption);
          floater.append(sigil, copy);

          // Damage owns the impact point. A newly exposed opening must read
          // as a second tactical result on that same target, not cover the
          // damage receipt before the player can tell whether Probe worked.
          const feedbackData = data.feedbackId === 'opening'
            ? { ...data, feedbackPlacement: 'target-offset' }
            : viewModel.tone === 'damage'
              ? { ...data, feedbackPlacement: 'target-clear' }
              : data;
          const staged = this.stagePresenter?.mountAtContact(floater, feedbackData, 'feedback');
          if (!staged) {
            targetEl.style.position = 'relative'; // Ensure relative parent
            targetEl.appendChild(floater);
          }

          setTimeout(() => {
              if (floater.parentNode) floater.parentNode.removeChild(floater);
          }, this._reducedMotion ? 220 : 1120);
      }
  }

  /* 不可用牌的拒绝反馈。
     玩家合同：按不下某张牌时，必须得到"为什么"和"下一步该做什么"，不能静默吞掉输入。
     原因分三类，文案与强度按"错误严重性"分级，不一视同仁：
       locked   —— 招式正在施展。属于"还没到时候"，只给抖动，不出文案，避免制造噪音。
       reaction —— 反应窗开启，必须先应对来招。给文案，因为这是玩家可以立刻纠正的操作。
       qi       —— 真元不足。给文案，因为这是玩家需要重新排布资源的选择。
     珊瑚红沿用费用牌 .card-cost 的 #ffbca2，保持"珊瑚红 = 不可负担"这一色彩语言唯一；
     音效不在本批处理：AudioManager 的 cue 目录属 B5B 批次地盘，此处不越界新增素材，
     拒绝音作为 B5B 的输入项记录。 */
  _showCardUnavailable(cardEl, reason) {
    if (!cardEl) return;
    cardEl.classList.remove('is-denied');
    // 强制重排以便连续点击时重放抖动动画
    void cardEl.offsetWidth;
    cardEl.classList.add('is-denied');
    window.setTimeout(() => cardEl.classList.remove('is-denied'), 260);

    const copy = reason === 'reaction' ? '先应对来招'
      : (reason === 'qi' ? '真元不足' : '');
    if (!copy) return;

    const rect = cardEl.getBoundingClientRect();
    if (!rect || rect.width <= 0 || rect.height <= 0) return;
    const floater = document.createElement('div');
    floater.className = 'floating-text combat-deny-text';
    floater.textContent = copy;
    floater.setAttribute('aria-hidden', 'true');
    floater.style.position = 'fixed';
    floater.style.left = `${rect.left + rect.width / 2}px`;
    floater.style.top = `${rect.top + rect.height * 0.5}px`;
    document.body.appendChild(floater);
    window.setTimeout(() => floater.remove(), 1000);
  }

  _escapeHtml(value) {
    return String(value ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  _clearReactionCountdown() {
    if (this._reactionCountdownTimer !== null) clearInterval(this._reactionCountdownTimer);
    this._reactionCountdownTimer = null;
  }

  _updateReactionDeadline(reaction) {
    if (!this.reactionMode || !reaction) return;
    if (reaction.mode !== 'timed' || !Number.isFinite(Number(reaction.deadlineAt))) {
      this.reactionMode.textContent = '暂停式 · 等待选择';
      return;
    }
    const remaining = Math.max(0, Number(reaction.deadlineAt) - Date.now());
    this.reactionMode.textContent = `计时式 · ${(remaining / 1000).toFixed(1)} 秒`;
  }

  _formatEffectiveActionDescription(action, fallback = '观察动作后选择回应。') {
    const effectiveDamage = Number(action?.expectedDamage);
    if (action?.type === 'attack' && Number.isFinite(effectiveDamage)) {
      return `预计造成 ${Math.max(0, effectiveDamage)} 点伤害${action?.piercing ? ' · 穿透' : ''}`;
    }
    return action?.description || fallback;
  }

  _renderReaction(reaction, phase) {
    this._clearReactionCountdown();
    this._activeReaction = phase === 'REACTION_OPEN' && reaction ? reaction : null;
    if (this.endTurnBtn) this.endTurnBtn.disabled = Boolean(this._activeReaction);
    if (this.handContainer) this.handContainer.setAttribute('aria-hidden', this._activeReaction ? 'true' : 'false');
    if (!this.reactionPanel || !this.reactionOptions) return;
    if (!this._activeReaction) {
      this.reactionPanel.hidden = true;
      this.reactionOptions.innerHTML = '';
      return;
    }

    const active = this._activeReaction;
    this.reactionPanel.hidden = false;
    this.reactionPanel.dataset.mode = active.mode || 'paused';
    this.reactionPanel.dataset.actionFamily = active.action?.actionFamily || 'SPECIAL';
    if (this.reactionKicker) this.reactionKicker.textContent = `第 ${active.turn || 1} 回合 · ${active.source || '敌方'} 已出手`;
    if (this.reactionTitle) this.reactionTitle.textContent = '在攻势落下前回应';
    if (this.reactionAction) this.reactionAction.textContent = active.action?.actionName || '敌方行动';
    if (this.reactionDescription) this.reactionDescription.textContent = this._formatEffectiveActionDescription(active.action);
    if (this.reactionDamage) {
      const damage = Math.max(0, Number(active.action?.expectedDamage) || 0);
      this.reactionDamage.textContent = damage > 0
        ? `预计 ${damage} 点伤害${active.action?.piercing ? ' · 穿透' : ''}`
        : '非直接伤害动作';
    }
    if (this.reactionHelp) {
      this.reactionHelp.textContent = active.mode === 'timed'
        ? '数字键可直接选择；倒计时结束将自动承受。'
        : '数字键可直接选择；暂停式不会自动结算。';
    }

    this.reactionOptions.innerHTML = '';
    (active.options || []).forEach((option, index) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'combat-reaction-option';
      button.dataset.reactionId = option.id;
      button.disabled = !option.available;
      button.setAttribute('aria-disabled', option.available ? 'false' : 'true');
      const cost = Math.max(0, Number(option.cost?.qi) || 0);
      button.setAttribute(
        'aria-label',
        `${index + 1}，${option.label}，${cost ? `消耗 ${cost} 点真元` : '不消耗真元'}，${option.available ? option.description : option.disabledReason}`
      );
      button.innerHTML = `
        <kbd>${index + 1}</kbd>
        <span><strong>${this._escapeHtml(option.label || option.id)}</strong><small>${this._escapeHtml(option.description || '')}</small></span>
        <em>${cost ? `${cost} 真元` : '0 消耗'}</em>
        ${option.available ? '' : `<i>${this._escapeHtml(option.disabledReason || '当前不可用')}</i>`}
      `;
      button.addEventListener('click', () => {
        if (option.available && typeof deckCombatSystem !== 'undefined') {
          deckCombatSystem.chooseReaction(option.id, active.windowId);
        }
      });
      this.reactionOptions.appendChild(button);
    });

    this._updateReactionDeadline(active);
    if (active.mode === 'timed') {
      this._reactionCountdownTimer = setInterval(() => this._updateReactionDeadline(active), 100);
    }
    if (this._lastReactionWindowId !== active.windowId) {
      this._lastReactionWindowId = active.windowId;
      requestAnimationFrame(() => {
        this.reactionOptions.querySelector('button:not([disabled])')?.focus();
      });
    }
  }

  _announceReactionMissed() {
    this._announceCombatLive('反应时间结束：自动选择承受。', {
      kind: 'result',
      durationMs: 2600
    });
  }

  // Authored body sheets are four frames long and their measured silhouette
  // difference sits around 4-15%: enough for a pose change, not enough to read
  // as an attack. Rather than re-cutting every sprite, the carrier is given a
  // per-frame motion offset that amplifies what the four frames already carry —
  // weight shift into the wind-up, travel into the contact frame, recovery out.
  // The pose still comes from the art; only its amplitude is lifted. Offsets
  // are expressed against the actor's own rendered height so they scale with
  // the viewport, and they are applied as a CSS variable rather than an inline
  // transform so the existing root-anchor transform keeps composing on top.
  _resolveActionFrameMotion(data = {}, animation = {}, index = 0, frameCount = 1) {
    if (animation.frameSetId === 'yelingyun_s1_sword_attack_probe_rework_v1') {
      return { x: 0, y: 0, scale: 1, rotate: 0 };
    }
    const groundedS1Cast = /^yelingyun_s1_(sword_intent|body_stance|spell_ward|pill_mending)_cast_v[12]$/
      .test(String(animation.frameSetId || ''));
    const family = String(data.actionFamily || 'skill').toLowerCase();
    const contact = String(data.stage?.contact || animation.contact || 'self');
    if (frameCount <= 1) return { x: 0, y: 0, scale: 1, rotate: 0 };
    // Normalised position through the beat, 0 at the first frame.
    const t = frameCount > 1 ? index / (frameCount - 1) : 0;
    // Where the authored contact sits. Prefer the metric, fall back to the
    // same middle-beat rule the hitstop uses.
    const declared = Number(animation.impactFrameIndex);
    const impactAt = Number.isFinite(declared) && declared > 0 && declared < frameCount
      ? declared / (frameCount - 1)
      : (frameCount >= 3 ? 1 / (frameCount - 1) * Math.floor(frameCount / 2) : 0.5);
    const reach = contact === 'melee' ? 1 : contact === 'projectile' ? 0.62 : 0.3;
    const lean = family === 'attack' ? 1 : family === 'guard' || family === 'hurt' ? 0.42 : 0.7;
    // Three-beat read: settle back before the contact, drive through it, then
    // bleed off. Each term is a windowed bump so each frame gets a distinct
    // offset instead of a linear tween between two poses.
    const windUp = Math.max(0, 1 - Math.abs(t - impactAt * 0.5) * 3.1);
    const contactBump = Math.max(0, 1 - Math.abs(t - impactAt) * 5.4);
    const followThrough = Math.max(0, 1 - Math.abs(t - (impactAt + (1 - impactAt) * 0.6)) * 4.2);
    // The carrier is a square sheet, so a percentage translate resolves against
    // its rendered box: on a ~306px actor, 1% is roughly 3px. `amp` is in that
    // same unit. Measured output for a sword attack is about +20% travel on the
    // contact frame and -9% on the wind-up, which reads as a step-in strike
    // without lifting the body out of its lane.
    const amp = 15 * reach * lean * 0.95;
    return {
      x: Number(((-windUp * 0.42 + contactBump * 1 + followThrough * 0.2) * amp).toFixed(2)),
      // Vertical travel is deliberately a fraction of the horizontal one. The
      // contact frame only needs to lift the body off its stance by a few
      // pixels; matching the horizontal amplitude here lifted the whole actor
      // out of the lane and read as a jump rather than a strike.
      y: groundedS1Cast ? 0 : Number(((contactBump * -1.8 + followThrough * 0.9) * amp * 0.16).toFixed(2)),
      scale: groundedS1Cast ? 1 : Number((1 + contactBump * 0.07 - windUp * 0.02).toFixed(3)),
      rotate: groundedS1Cast ? 0 : Number(((contactBump * 1.6 - windUp * 1.1) * amp / 7).toFixed(2))
    };
  }

  _resolveActionCarrierContract(data = {}, animation = {}, frames = []) {
    const world = this._currentContext?.visualWorld;
    const side = data.source === 'enemy' ? 'enemy' : 'player';
    const actorCard = this._currentContext?.actorCards?.[side];
    const bodyProfileId = actorCard?.scaleProfileId;
    const bodyProfile = world?.actorBodyProfiles?.[bodyProfileId];
    const metric = world?.actionCarrierMetrics?.[animation.frameSetId];
    const staticCarrier = this._resolveActorCarrierMetric(actorCard, world, null, actorCard?.image)?.metric;
    const metricFramePaths = Array.isArray(metric?.frameFiles)
      ? metric.frameFiles.map(frame => this._normaliseVisualAssetPath(frame?.path)).filter(Boolean)
      : [];
    const animationFramePaths = frames.map(frame => this._normaliseVisualAssetPath(frame)).filter(Boolean);
    const frameGroundAnchors = Array.isArray(metric?.groundAnchor?.frameY)
      ? metric.groundAnchor.frameY
      : [];
    const frameRootAnchors = Array.isArray(metric?.rootAnchor?.framePoints)
      ? metric.rootAnchor.framePoints
      : [];
    const frameBodyBounds = Array.isArray(metric?.bodyBounds?.frameRects)
      ? metric.bodyBounds.frameRects
      : [];
    const frameRenderBounds = Array.isArray(metric?.renderBounds?.frameRects)
      ? metric.renderBounds.frameRects
      : [];
    const actionScaleRecord = world?.actionScaleBindings?.[animation.frameSetId];
    const authoredActionScale = metric?.authoredActionScale;
    const near = (left, right, tolerance = 0.000001) => Number.isFinite(Number(left))
      && Number.isFinite(Number(right)) && Math.abs(Number(left) - Number(right)) <= tolerance;
    const strictProfileBindingCompatible = bodyProfile?.spatialContractId !== 'actor_spatial_v1'
      || (actionScaleRecord?.bodyProfileContractSha256 === bodyProfile?.bodyProfileContractSha256
        && ['speciesId', 'morphologyId', 'progressionStageId', 'combatRoleId'].every(field =>
          actionScaleRecord?.authoredScaleBasis?.[field] === bodyProfile?.authoredScaleBasis?.[field]));
    const authoredFacingCompatible = !metric?.authoredFacing
      || (metric.authoredFacing === animation.authoredFacing
        && metric.runtimeFacingPolicy === 'toward_primary_target_mirror_carrier_only_when_needed'
        && actionScaleRecord?.authoredFacing === metric.authoredFacing
        && actionScaleRecord?.runtimeFacingPolicy === metric.runtimeFacingPolicy);
    const actionScaleCompatible = Boolean(actionScaleRecord
      && authoredActionScale?.source === 'external_action_scale_provenance_v1'
      && authoredActionScale.frameSetId === animation.frameSetId
      && authoredActionScale.recordId === actionScaleRecord.recordId
      && actionScaleRecord.frameSetId === animation.frameSetId
      && actionScaleRecord.bodyProfileId === bodyProfileId
      && strictProfileBindingCompatible
      && authoredFacingCompatible
      && near(actionScaleRecord.referenceHeight, metric?.referenceHeight)
      && near(actionScaleRecord.referenceHeight, metric?.scaleReference?.bodyReferenceHeight)
      && actionScaleRecord.scalePolicy === metric?.scaleReference?.policy
      && actionScaleRecord.referenceMetricId === metric?.scaleReference?.referenceMetricId
      && actionScaleRecord.mountMetricsPath === metric?.scaleReference?.mountMetricsPath
      && actionScaleRecord.mountMetricsSha256 === metric?.scaleReference?.mountMetricsSha256
      && actionScaleRecord.generationSummaryPath === metric?.scaleReference?.generationSummaryPath
      && actionScaleRecord.generationSummarySha256 === metric?.scaleReference?.generationSummarySha256
      && actionScaleRecord.profilePath === metric?.scaleReference?.profilePath
      && actionScaleRecord.profileSha256 === metric?.scaleReference?.profileSha256
      && Array.isArray(actionScaleRecord.frameFiles)
      && actionScaleRecord.frameFiles.length === metricFramePaths.length
      && actionScaleRecord.frameFiles.every((frame, index) =>
        this._normaliseVisualAssetPath(frame?.path) === metricFramePaths[index]
          && frame?.sha256 === metric?.frameFiles?.[index]?.sha256));
    const acceptedScalePolicies = new Set([
      'path_attack_anatomy_reference_uniform_runtime_canvas',
      'stage_attack_anatomy_reference_uniform_runtime_canvas',
      'identity_anatomy_reference_uniform_runtime_canvas',
      'identity_formation_reference_uniform_runtime_canvas'
    ]);
    const acceptedContactSources = new Set([
      'frame_local_mount_metrics_center_mass_with_body_profile_semantic_fallback',
      'frame_local_structural_annotation_with_body_profile_semantic_fallback',
      'frame_local_formation_center_with_body_profile_semantic_fallback'
    ]);
    const acceptedRootSources = new Set([
      'authored_mount_pose_root',
      'authored_shadow_projection_root',
      // Generated enemy poses are normalized from their final alpha support,
      // so each frame may own a measured root instead of borrowing identity Y.
      'measured_per_frame_visible_support'
    ]);
    const measuredPoseContract = metric?.bodyBounds?.source === 'verified_mount_metrics_cleaned_actor_carrier'
      && metric?.renderBounds?.source === 'measured_alpha_content'
      && acceptedRootSources.has(metric?.rootAnchor?.source)
      && metric?.groundAnchor?.source === metric?.rootAnchor?.source
      && acceptedScalePolicies.has(metric?.scaleReference?.policy)
      && acceptedContactSources.has(metric?.contactAnchors?.source);
    const referenceHeight = Number(metric?.referenceHeight);
    const compatible = Boolean(metric
      && bodyProfile
      && metric.bodyProfileId === bodyProfileId
      && measuredPoseContract
      && actionScaleCompatible
      && this._isBodyProfileCompatible(bodyProfile, world)
      && staticCarrier?.bodyProfileId === bodyProfileId
      && this._isCarrierMetricCompatible(staticCarrier, bodyProfile, world)
      && metricFramePaths.length === animationFramePaths.length
      && metricFramePaths.every((frame, index) => frame === animationFramePaths[index])
      && frameGroundAnchors.length === animationFramePaths.length
      && frameGroundAnchors.every(anchor => typeof anchor === 'number' && anchor > 0 && anchor <= 1)
      && frameRootAnchors.length === animationFramePaths.length
      && frameRootAnchors.every(anchor => this._isUnitPoint(anchor))
      && frameBodyBounds.length === animationFramePaths.length
      && frameBodyBounds.every(bounds => this._isUnitRect(bounds))
      && frameRenderBounds.length === animationFramePaths.length
      && frameRenderBounds.every(bounds => this._isUnitRect(bounds))
      && Number.isFinite(referenceHeight) && referenceHeight > 0);
    return compatible
      ? { metric, bodyProfileId, referenceHeight, frameGroundAnchors, frameRootAnchors, frameBodyBounds }
      : null;
  }

  _resolveMatchedActionCanvas(data = {}, animation = {}, frames = [], actor = null) {
    const playerFamily = String(data.actionFamily || '');
    const matchedPlayer = data.source === 'player' && (
      (animation.visualStageId === 'S1_outer_novice'
        && ['attack', 'skill', 'guard', 'reaction'].includes(playerFamily))
      || (animation.visualStageId === 'S2_resonant_disciple'
        && playerFamily === 'reaction')
    );
    const world = this._currentContext?.visualWorld;
    const actorCard = this._currentContext?.actorCards?.[data.source];
    // This authored enemy has a verified idle carrier and action frame roots.
    // Its 384px action sheet has more transparent margin than its idle sheet;
    // using 100% of the actor box makes the same body visibly shrink.
    const matchedOuterGuard = data.source === 'enemy'
      && actorCard?.scaleProfileId === 'outer_guard_disciplined_humanoid_n8';
    const matchedSwiftDummy = data.source === 'enemy'
      && actorCard?.scaleProfileId === 'quick_sword_dummy_humanoid'
      && animation.frameSetId === 'quick_sword_dummy_attack_agc_m1';
    if (!matchedPlayer && !matchedOuterGuard && !matchedSwiftDummy) return null;
    const metric = world?.actionCarrierMetrics?.[animation.frameSetId];
    const staticMetric = this._resolveActorCarrierMetric(actorCard, world, null, actorCard?.image)?.metric;
    const referenceHeight = Number(metric?.referenceHeight);
    const staticBodyHeight = Number(staticMetric?.bodyBounds?.height);
    const metricPaths = metric?.frameFiles?.map(frame => this._normaliseVisualAssetPath(frame?.path));
    const expectedPaths = frames.map(frame => this._normaliseVisualAssetPath(frame));
    const card = actor?.closest?.('.combat-actor-card');
    const idleCanvasHeight = Number.parseFloat(card?.style?.getPropertyValue('--actor-canvas-height'));
    if (metric?.bodyProfileId !== actorCard?.scaleProfileId
      || !Array.isArray(metricPaths) || metricPaths.length !== expectedPaths.length
      || !metricPaths.every((frame, index) => frame === expectedPaths[index]
        && /^[a-f0-9]{64}$/.test(String(metric.frameFiles[index]?.sha256 || '')))
      || !(referenceHeight > 0.25 && referenceHeight < 0.95)
      || !(staticBodyHeight > 0 && staticBodyHeight <= 1)
      || !(idleCanvasHeight > 50 && idleCanvasHeight < 300)) return null;
    const heightPercent = idleCanvasHeight * staticBodyHeight / referenceHeight;
    if (!(heightPercent > 75 && heightPercent < 280)) return null;
    return { heightPercent, referenceHeight, staticBodyHeight };
  }

  _scheduleTerminalPresentationHide(data = {}, delay = 1, details = {}) {
    if (data.terminal !== true) return false;
    clearTimeout(this._terminalPresentationHideTimer);
    this._terminalPresentationHideTimer = setTimeout(() => {
      this._terminalPresentationHideTimer = null;
      eventBus.emit('ui:hideCombatScreen', {
        terminalPresentation: true,
        actionId: String(data.actionId || ''),
        frameSetId: data.animation?.frameSetId || null,
        visualLifecycleCompleted: true,
        ...details
      });
    }, Math.max(1, Number(delay) || 1));
    return true;
  }

  _resolveSemanticActionVisualDuration(data = {}, frameDurations = [], fallbackDuration = 1) {
    const frameSequenceDuration = Array.isArray(frameDurations) && frameDurations.length > 0
      && frameDurations.every(duration => Number.isFinite(Number(duration)) && Number(duration) >= 16)
      ? frameDurations.reduce((sum, duration) => sum + Number(duration), 0)
      : 0;
    const authoritativeDuration = Math.max(0, Number(data?.duration) || 0);
    return Math.max(1, authoritativeDuration, frameSequenceDuration,
      Math.max(0, Number(fallbackDuration) || 0));
  }

  // Hitstop length for one contact, in the three authored tiers.
// Deliberately a runtime lookup rather than a literal: PC98 pixel pacing is
// fast, and the right window has to be decided by feel in the browser, not
// fixed in a data file that nobody plays against.
  _resolveImpactHitstop(data = {}, animation = {}) {
    const tier = String(data?.impactHitstopTier || this._impactHitstopTier || 'medium');
    const base = { short: 20, medium: 40, long: 60 }[tier];
    if (!Number.isFinite(base)) return 40;
    const contact = String(data?.stage?.contact || animation?.contact || 'self');
    const weight = contact === 'melee' ? 1 : contact === 'projectile' ? 0.8 : 0.5;
    return Math.max(0, Math.round(base * weight));
  }

  setImpactHitstopTier(tier = 'medium') {
    const allowed = new Set(['short', 'medium', 'long']);
    const next = String(tier);
    this._impactHitstopTier = allowed.has(next) ? next : 'medium';
    if (this.container?.dataset) this.container.dataset.impactHitstopTier = this._impactHitstopTier;
    return this._impactHitstopTier;
  }

  _onSemanticActionStarted(data = {}) {
    const actor = data.source === 'enemy' ? this.enemySprite : this.playerSprite;
    this._clearReactionActorResidue(actor);
    if (!actor || !data.actionId) {
      // Record why an action never reached start(): a missing actor sprite is
      // an earlier gate than geometry, and it is invisible without a counter.
      this._countStageFx('actionStarted');
      this._countStageFx(!actor ? 'skippedNoActor' : 'skippedNoActionId');
      return 'skipped';
    }
    const actorContainer = actor.closest('.enemy-area, .player-area');
    const animation = data.animation || {};
    const authoredFrames = Array.isArray(animation.frames)
      ? animation.frames.filter(frame => typeof frame === 'string' && frame.trim())
      : [];
    // A valid frame_sequence under reduced motion must still show the character
    // performing its action — as a single frozen key pose rather than a flashing
    // empty body. Previously, only terminal frames took the static path; non-
    // terminal actions under reduced motion fell through to the bare
    // is-semantic-action-active flash with no frame mounted (the reported
    // "角色只闪一下"). Reduced motion holds the effect key pose for normal
    // actions, while terminal actions retain their final state.
    const hasRenderableSequence = animation.kind === 'frame_sequence'
      && animation.motionApproved === true
      && authoredFrames.length >= 2;
    const reducedMotionStatic = this._reducedMotion === true;
    const useStaticTerminalFrame = (reducedMotionStatic && hasRenderableSequence)
      || (reducedMotionStatic
        && (data.terminalActorState === true || data.terminal === true)
        && animation.kind === 'frame_sequence'
        && animation.motionApproved === true
        && authoredFrames.length > 0);
    const declaredKeyPose = Number(animation.impactFrameIndex);
    const staticFrameIndex = data.terminalActorState === true || data.terminal === true
      ? authoredFrames.length - 1
      : Number.isInteger(declaredKeyPose) && declaredKeyPose >= 0 && declaredKeyPose < authoredFrames.length
        ? declaredKeyPose : Math.max(0, Math.floor(authoredFrames.length / 2));
    const frames = useStaticTerminalFrame
      ? [authoredFrames[staticFrameIndex]]
      : authoredFrames;
    const frameMetricIndices = useStaticTerminalFrame
      ? [staticFrameIndex]
      : frames.map((_, index) => index);
    const blockedByUnresolvedVisualWorld = animation.kind === 'frame_sequence'
      && animation.motionApproved === true
      && this.container?.dataset?.requestedMediaAllowed === 'false';
    if (blockedByUnresolvedVisualWorld) {
      // Scene portraits and VFX already fail closed when a reviewed world was
      // requested but its scale/composition contract did not resolve. Body
      // sequences must obey that same gate; otherwise an unmeasured action can
      // leak over an intentionally hidden actor and silently style-mix worlds.
      this._clearSemanticActionsForActor(actor, {
        discardPresentationQueue: data._presentationDequeued !== true
      });
      actor.dataset.actionCarrierMetricStatus = 'blocked-unresolved-visual-world';
      actor.classList.remove('is-semantic-action-active');
      actorContainer?.classList.remove('is-semantic-action-active');
      delete actor.dataset.combatActionId;
      delete actor.dataset.combatActionFamily;
      const terminalScheduled = this._scheduleTerminalPresentationHide(data, 1, {
        fallbackReason: 'unresolved_visual_world'
      });
      return terminalScheduled ? 'terminal_wait' : 'skipped';
    }
    if (data.source === 'player'
      && animation.kind === 'frame_sequence'
      && animation.motionApproved === true
      && !animation.stageFallback
      && !this._isPlayerSequenceCompatibleWithDisplayedStage(animation, data)) {
      // A `stageFallback` animation is the baseline approved frame_sequence the
      // system deliberately kept after a stage-specific variant was unavailable
      // (see DeckCombatSystem._resolveSemanticActionContract). The character must
      // still perform its motion — the variant was a refinement, never the gate
      // on whether the body animates. Skipping it here would drop back to the
      // bare is-semantic-action-active flash instead of a real pose.
      return this._scheduleTerminalPresentationHide(data, 1, { fallbackReason: 'incompatible_visual_stage' })
        ? 'terminal_wait' : 'skipped';
    }
    // Settlement closes combat before the terminal pose is shown.  The final
    // presentation is still a player-owned visual action, but the previous
    // reaction chooser is no longer actionable and would otherwise cover the
    // character at narrow viewport sizes because no combat:updated event is
    // emitted after the terminal state becomes IDLE.
    if (data.terminal === true) this._renderReaction(null, 'IDLE');
    // A reaction is deliberately presentation-only while the authoritative enemy
    // resolution remains synchronous. A real hurt sequence can be emitted in
    // that same task. Queue only that visual continuation so the player sees the
    // chosen reaction before its consequence; never defer combat settlement.
    const queueAfterPlayerReaction = data.source === 'player'
      && data.actionFamily === 'hurt'
      && animation.kind === 'frame_sequence'
      && animation.motionApproved === true
      && [...this._semanticActionRuns.values()].some(run => run.actor === actor && run.presentationOnly);
    if (queueAfterPlayerReaction) {
      this._enqueueSemanticPresentation(actor, data);
      return 'queued';
    }
    // A narrow battlefield can preserve authored body scale only if visual body
    // sequences follow the actual exchange clock: source action, then target
    // response. Authoritative combat remains synchronous, but a later body
    // carrier must not be mounted over a still-visible carrier from the other
    // actor. This makes the viewport solve active-primary + passive-static,
    // instead of the impossible Cartesian product of every action frame.
    const serializedExchange = this.container?.dataset?.exchangeChoreographyPolicyId
      === 'serialized_active_body_v1';
    const hasRenderableBodySequence = animation.kind === 'frame_sequence'
      && animation.motionApproved === true && frames.length >= 2;
    const hasQueuedSerializedPresentation = serializedExchange
      && [...this._semanticPresentationQueues.values()].some(queue => queue?.length);
    const authoredReactionSidecar = data.source === 'player'
      && data.presentationOnly === true
      && String(data.actionFamily || '').toLowerCase() === 'reaction';
    const blockedBySerializedBody = serializedExchange && hasRenderableBodySequence
      && !authoredReactionSidecar
      && data._presentationDequeued !== true
      && (this._semanticActionRuns.size > 0 || hasQueuedSerializedPresentation);
    // ── 状态机契约裁决（T-01 真正生效的地方）────────────────────────────
    // 契约不只是打标签：这里用 interruptPriority + canInterruptBy 决定新动作
    // 能不能**立刻**打断同一角色正在播的动作。命中则先清掉旧演出再继续挂载，
    // 否则完全交回既有的序列化排队逻辑（不改动任何既有策略）。
    const interruptDecision = this._resolveStateMachineInterrupt(actor, data);
    if (interruptDecision === 'interrupt') {
      const currentRunId = [...this._semanticActionRuns.entries()]
        .find(([, run]) => run.actor === actor)?.[0];
      if (currentRunId) {
        const previous = this._animationStateFor(
          this._semanticActionRuns.get(currentRunId)?.actionFamily
        )?.id || 'unknown';
        actor.dataset.animationStateInterruptedBy = String(data.actionFamily || '');
        actor.dataset.animationStateInterruptedFrom = previous;
        this._clearSemanticAction(currentRunId, { drainPresentationQueue: false });
        actor.classList.remove('is-semantic-action-active');
        actor.closest?.('.enemy-area, .player-area')?.classList.remove('is-semantic-action-active');
        this._reflowPathSynergyCues();
      }
    }
    if (blockedBySerializedBody) {
      this._enqueueSemanticPresentation(actor, data);
      return 'queued';
    }
    // Capture actual visible resting labels before the body action hides
    // them. This is transient layout evidence, never combat/save authority.
    if (typeof getComputedStyle === 'function') {
      const resting = { viewport: `${innerWidth}x${innerHeight}`, obstacles: [] };
      for (const element of [this.playerKicker, this.enemyKicker]) {
        if (!element || element.closest('.is-semantic-action-active')) continue;
        const rect = element.getBoundingClientRect(), style = getComputedStyle(element);
        if (style.display === 'none' || style.visibility === 'hidden' || !(rect.width > 0 && rect.height > 0)) continue;
        const saved = { left: rect.left, right: rect.right, top: rect.top, bottom: rect.bottom,
          width: rect.width, height: rect.height };
        resting.obstacles.push(saved);
        if (element === this.playerKicker) resting.playerIdentity = saved;
      }
      if (resting.playerIdentity) this._pathSynergyRestGeometry = resting;
    }
    const deferStageClock = animation.kind === 'frame_sequence'
      && animation.motionApproved === true
      && (useStaticTerminalFrame || (!this._reducedMotion && frames.length >= 2));
    this.stagePresenter?.start(data, { deferClock: deferStageClock });
    this._countStageFx('actionStarted');
    this._countStageFx(data?.stage && this.stagePresenter?.actions?.has?.(String(data.actionId || ''))
      ? 'startRegistered' : 'startRefused');
    this._flushPendingVfxForAction(data.actionId);
    this._flushPathSynergyForAction(data.actionId);
    const preservePendingPlayerPresentation = data.source === 'player'
      && animation.kind !== 'frame_sequence'
      && [...this._semanticActionRuns.values()].some(run => run.actor === actor && run.presentationOnly);
    if (!preservePendingPlayerPresentation) {
      // In a serialized exchange, this body may have a later same-actor
      // continuation already waiting (hurt -> defeat is the fatal case).
      // Clear the mounted carrier, never the authoritative FIFO tail.
      this._clearSemanticActionsForActor(actor, {
        discardPresentationQueue: !serializedExchange
      });
      actor.dataset.combatActionId = String(data.actionId);
      actor.dataset.combatActionFamily = String(data.actionFamily || 'skill');
      if (!deferStageClock) {
        actor.classList.add('is-semantic-action-active');
        actorContainer?.classList.add('is-semantic-action-active');
      }
      if (this.actionLayer) this.actionLayer.dataset.activeActionId = String(data.actionId);
    }

    this._reflowPathSynergyCues();
    if ((this._reducedMotion && !useStaticTerminalFrame)
      || animation.kind !== 'frame_sequence'
      || animation.motionApproved !== true
      || (!useStaticTerminalFrame && frames.length < 2)) {
      if (data.terminal === true) {
        const fallbackHold = this._reducedMotion ? 160 : Math.max(1, Number(data.duration) || 1);
        this._scheduleTerminalPresentationHide(data, fallbackHold, {
          reducedMotion: this._reducedMotion,
          fallbackReason: this._reducedMotion ? 'reduced_motion' : 'untimed_terminal_carrier'
        });
        return 'terminal_wait';
      }
      return 'skipped';
    }

    const frameDurations = Array.isArray(animation.frameDurations)
      ? animation.frameDurations.map(value => Math.max(16, Number(value) || 0))
      : [];
    const actionId = String(data.actionId);
    const overlay = document.createElement('img');
    overlay.className = 'combat-semantic-frame-sequence';
    overlay.alt = '';
    overlay.draggable = false;
    overlay.setAttribute('aria-hidden', 'true');
    overlay.dataset.actionId = actionId;
    overlay.dataset.frameSetId = String(animation.frameSetId || '');
    overlay.dataset.frameIndex = String(frameMetricIndices[0]);
    if (useStaticTerminalFrame) overlay.classList.add('is-reduced-motion-terminal-state');
    const actionCarrierContract = this._resolveActionCarrierContract(data, animation, authoredFrames);
    const actionCarrierResolved = Boolean(actionCarrierContract);
    const matchedCanvas = this._resolveMatchedActionCanvas(data, animation, authoredFrames, actor);
    const actionCanvasHeight = matchedCanvas?.heightPercent || 100;
    const alignedBottom = feetY => -(1 - feetY) * actionCanvasHeight;
    if (matchedCanvas) overlay.dataset.bodyScaleStatus = 'matched-idle-body';
    // Frame motion is independent of the carrier contract: it amplifies the
    // authored pose and has to survive the measured-feet-only path, where the
    // contract is absent and the action still plays.
    const applyActionFrameMotion = index => {
      const motion = this._resolveActionFrameMotion(data, animation, index, frames.length);
      // Offsets are relative to the carrier's own rendered height, so the
      // same authored numbers read the same on desktop and on a narrow
      // viewport, and the rule never depends on a layout variable that is
      // only written once the actor has been measured.
      overlay.style.setProperty('--actor-action-motion-x', `${motion.x}%`);
      overlay.style.setProperty('--actor-action-motion-y', `${motion.y}%`);
      overlay.style.setProperty('--actor-action-motion-scale', String(motion.scale));
      overlay.style.setProperty('--actor-action-motion-rotate', `${motion.rotate}deg`);
      overlay.dataset.motionX = String(motion.x);
      overlay.dataset.motionRotate = String(motion.rotate);
      return true;
    };

    let measuredGroundAnchors = null;
    const applyActionFrameMetric = index => {
      applyActionFrameMotion(index);
      if (!actionCarrierContract) {
        const measuredFeet = Number(measuredGroundAnchors?.[frameMetricIndices[index]]);
        if (Number.isFinite(measuredFeet) && measuredFeet > 0 && measuredFeet <= 1) {
          overlay.style.setProperty('--actor-action-canvas-bottom', `${alignedBottom(measuredFeet).toFixed(3)}%`);
          overlay.dataset.feetAnchorRatio = String(measuredFeet);
        }
        return false;
      }
      const metricIndex = frameMetricIndices[index];
      const actionFeetY = Number(actionCarrierContract.frameGroundAnchors[metricIndex]);
      const actionRoot = actionCarrierContract.frameRootAnchors[metricIndex];
      // Mount the action canvas at the carrier box, not at the authored body
      // fraction. `100 / referenceHeight` rendered every sequence at roughly
      // 1.5x–2.3x the actor box, which is what left a large frame floating
      // outside the body. The authored margins differ per sheet (a 320px sheet
      // carries less than a 384px one); `object-fit: contain` absorbs that
      // difference, while `feetY` places the contact line on the ground.
      overlay.style.setProperty('--actor-action-canvas-height', `${actionCanvasHeight.toFixed(3)}%`);
      // Height establishes the one uniform canvas scale.  Let the <img>
      // derive its width from the source pixels; reusing the idle carrier's
      // width percentage here independently scaled X and Y, compressing
      // human actions and widening construct actions.
      overlay.style.setProperty('--actor-action-canvas-width', 'auto');
      // The canvas is anchored by its own frame-local feet line, not by the
      // body unit.  `actionFeetY` is a fraction of the source canvas and
      // `referenceHeight` is a fraction of the character height, so the two
      // cannot be combined into one percentage: doing so shifted the rendered
      // feet by the difference between the two scales, which is how a 320px
      // sheet and a 384px sheet ended up standing at different heights.
      // object-fit is `contain`, so the visible box is the whole canvas; the
      // feet line therefore sits at `actionFeetY` of the rendered box.
      const canvasFeetPercent = Number.isFinite(actionFeetY) ? actionFeetY * 100 : 100;
      overlay.style.setProperty('--actor-action-canvas-bottom', `${alignedBottom(canvasFeetPercent / 100).toFixed(3)}%`);
      overlay.style.setProperty('--actor-action-root-shift-x', `${(-Number(actionRoot.x) * 100).toFixed(3)}%`);
      overlay.style.setProperty('--actor-action-root-x', `${(Number(actionRoot.x) * 100).toFixed(3)}%`);
      overlay.dataset.frameGroundAnchor = String(actionFeetY);
      overlay.dataset.feetAnchorRatio = String(actionFeetY);
      overlay.dataset.rootAnchorX = String(actionRoot.x);
      overlay.dataset.rootAnchorY = String(actionRoot.y);
      overlay.dataset.rootMotionX = String(actionCarrierContract.metric.rootAnchor.rootMotion?.[metricIndex]?.x || 0);
      overlay.dataset.rootMotionY = String(actionCarrierContract.metric.rootAnchor.rootMotion?.[metricIndex]?.y || 0);
      return true;
    };
    if (actionCarrierResolved) {
      applyActionFrameMetric(0);
      overlay.dataset.carrierMetricStatus = 'resolved';
      overlay.dataset.carrierMetricId = String(animation.frameSetId || '');
      overlay.dataset.bodyProfileId = actionCarrierContract.bodyProfileId;
      overlay.dataset.bodyBoundsStatus = 'verified-mount-metrics';
      overlay.dataset.contactAnchorStatus = 'frame-local-with-profile-fallback';
      actor.dataset.actionCarrierMetricStatus = 'resolved';
    } else {
      // A frame set can carry measured ground truth in the carrier metrics
      // without carrying a full authored scale binding — the binding also
      // demands provenance files that only the measurement step produces. When
      // the feet line is known, mount the sequence on it rather than dropping
      // the whole action: the strict binding still decides whether the world
      // may resolve, this only decides where the feet land.
      // The measured feet line is the one number that decides where an actor
      // stands.  A frame set can carry it without carrying the full authored
      // scale binding, because the binding also demands provenance files that
      // only the measurement step emits.  `_currentContext.visualWorld` is
      // null whenever the world is unresolved, so read the registry directly
      // rather than refusing to mount the action at all.
      let measuredFeet = NaN;
      const contextWorld = this._currentContext?.visualWorld;
      const registryWorld = (typeof dataLoader !== 'undefined' && dataLoader?.loadSync
        ? dataLoader.loadSync('combat:visual_worlds')
        : null);
      const metricSource = contextWorld
        || (registryWorld && Object.values(registryWorld.worlds || registryWorld)[0])
        || null;
      const metric = metricSource?.actionCarrierMetrics?.[animation.frameSetId] || null;
      if (metric) {
        const groundSeries = metric.groundAnchor?.frameY;
        if (Array.isArray(groundSeries) && groundSeries.length === authoredFrames.length
          && groundSeries.every(value => Number(value) > 0 && Number(value) <= 1)) {
          measuredGroundAnchors = groundSeries.map(Number);
        }
        measuredFeet = Number(metric.feetY);
        if (!Number.isFinite(measuredFeet) || measuredFeet <= 0 || measuredFeet > 1) {
          // Fall back to the authored ground-anchor series when the top-level
          // feet line is missing: the measured series still pins the contact
          // line, so a frame set without a single summary feetY still lands
          // correctly instead of silently floating.
          const groundSeries = metric.groundAnchor?.frameY;
          if (Array.isArray(groundSeries) && groundSeries.length) {
            const sample = groundSeries[Math.min(
              groundSeries.length - 1,
              Math.max(0, Math.floor(groundSeries.length / 2))
            )];
            const sampled = Number(sample);
            if (Number.isFinite(sampled) && sampled > 0 && sampled <= 1) measuredFeet = sampled;
          }
        }
      }
      // Apply the same canvas sizing the resolved path uses, so an action that
      // falls back here keeps the actor at the size its siblings render at.
      if (Number.isFinite(measuredFeet) && measuredFeet > 0 && measuredFeet <= 1) {
        overlay.style.setProperty('--actor-action-canvas-height', `${actionCanvasHeight.toFixed(3)}%`);
        overlay.style.setProperty('--actor-action-canvas-width', 'auto');
        overlay.style.setProperty('--actor-action-canvas-bottom', `${alignedBottom(measuredGroundAnchors?.[frameMetricIndices[0]] || measuredFeet).toFixed(3)}%`);
        overlay.dataset.feetAnchorRatio = String(measuredGroundAnchors?.[frameMetricIndices[0]] || measuredFeet);
        overlay.dataset.carrierMetricStatus = 'measured-feet-only';
        overlay.dataset.carrierMetricId = String(animation.frameSetId || '');
        actor.dataset.actionCarrierMetricStatus = 'measured-feet-only';
        applyActionFrameMotion(0);
      } else if (this._currentContext?.visualWorldCompatible) {
      // A reviewed visual world must never fail open to an unmeasured carrier:
      // retain the stable actor portrait and expose the missing contract for
      // evidence instead of flashing a differently scaled or styled body.
      actor.dataset.actionCarrierMetricStatus = 'missing';
        actor.classList.remove('is-semantic-action-active');
        actorContainer?.classList.remove('is-semantic-action-active');
        delete actor.dataset.combatActionId;
        delete actor.dataset.combatActionFamily;
        if (this.actionLayer?.dataset.activeActionId === actionId) {
          delete this.actionLayer.dataset.activeActionId;
        }
        return this._scheduleTerminalPresentationHide(data, 1, { fallbackReason: 'missing_action_carrier_metric' })
          ? 'terminal_wait' : 'skipped';
      } else {
        // Resilient last resort: a valid frame_sequence must never disappear just
        // because the carrier metric is incomplete. Mount it on the bottom of the
        // actor box (feet at the floor) so the body still animates at a sane
        // position instead of dropping to a bare is-semantic-action-active flash.
        overlay.style.setProperty('--actor-action-canvas-height', '100%');
        overlay.style.setProperty('--actor-action-canvas-width', 'auto');
        overlay.style.setProperty('--actor-action-canvas-bottom', '0%');
        overlay.dataset.carrierMetricStatus = 'resilient-default';
        overlay.dataset.carrierMetricId = String(animation.frameSetId || '');
        actor.dataset.actionCarrierMetricStatus = 'resilient-default';
        applyActionFrameMotion(0);
      }
    }
    // Action exports have one authored horizontal direction.  The battle
    // layout supplies the actual target lane, so a declared target-facing
    // body action mirrors its transparent carrier only when needed.  This is
    // presentation geometry: it does not alter timing, target selection,
    // damage, input, or saved combat state.
    const authoredFacing = ['left', 'right'].includes(animation.authoredFacing)
      ? animation.authoredFacing
      : null;
    let resolvedFacing = authoredFacing;
    if (['toward_target', 'toward_threat'].includes(animation.facing) && authoredFacing) {
      // A self guard targets its owner mechanically, but its body must still
      // face the incoming threat.  Resolve that actor from semantic source;
      // if the opponent is not mounted, retain the authored direction.
      const targetActor = animation.facing === 'toward_threat'
        ? (data.source === 'enemy' ? this.playerSprite : this.enemySprite)
        : (data.target === 'player' ? this.playerSprite : this.enemySprite);
      const sourceRect = actor.getBoundingClientRect();
      const targetRect = targetActor?.getBoundingClientRect();
      if (targetRect && targetRect.width > 0) {
        const targetFacing = (targetRect.left + targetRect.width / 2) >= (sourceRect.left + sourceRect.width / 2)
          ? 'right'
          : 'left';
        resolvedFacing = targetFacing;
        if (targetFacing !== authoredFacing) {
          overlay.classList.add('is-mirrored');
          overlay.dataset.mirrored = 'true';
        }
      }
    }
    if (resolvedFacing) overlay.dataset.facing = resolvedFacing;
    // Body exports intentionally retain transparent safety margin.  A bottom
    // anchored canvas is not necessarily a feet anchored body: use the
    // measured normalized feet line when authoring supplies it, so this one
    // action lands on the actor's ground instead of visibly floating above it.
    // This only writes a DOM presentation offset; no combat or saved state is
    // changed, and legacy assets without a measured anchor keep their current
    // authored placement.
    const feetAnchorRatio = Number(animation.feetAnchorRatio);
    if (!actionCarrierResolved && !measuredGroundAnchors
      && ['feet', 'rooted'].includes(animation.anchor) && Number.isFinite(feetAnchorRatio)
      && feetAnchorRatio > 0 && feetAnchorRatio <= 1) {
      const alignMeasuredFeet = () => {
        if (!overlay.isConnected) return;
        const canvasHeight = Number.parseFloat(getComputedStyle(overlay).height);
        if (!Number.isFinite(canvasHeight) || canvasHeight <= 0) return;
        const bottomOffset = -Math.round(canvasHeight * (1 - feetAnchorRatio));
        overlay.style.bottom = `${bottomOffset}px`;
        overlay.dataset.feetAnchorRatio = String(feetAnchorRatio);
      };
      requestAnimationFrame(alignMeasuredFeet);
    }
    // The first visible body pose starts the presentation clock; contact
    // effects then wait for its authored contact pose rather than a timer race.

    const run = {
      actor,
      actorContainer,
      overlay,
      timeouts: [],
      animationFrames: [],
      watchdog: null,
      completed: false,
      presentationOnly: data.presentationOnly === true,
      actionFamily: String(data.actionFamily || '').toLowerCase(),
      terminal: data.terminal === true,
      terminalActorState: data.terminalActorState === true,
      projectileImpact: data.stage?.contact === 'projectile',
      locksPlayerInput: data.source === 'player' && data.presentationOnly !== true,
      frameSetId: String(animation.frameSetId || ''),
      currentFrameIndex: -1,
      pendingImpactData: null,
      visualImpactShown: false,
      visualContactShown: false
    };
    this._semanticActionRuns.set(actionId, run);
    if (run.locksPlayerInput) eventBus.emit('combat:visualActionMounted', { actionId });
    // 状态机：把当前状态写到 DOM 供样式层读取，并挂看门狗防卡死（T-02）。
    const animStateId = this._animationStateFor(data.actionFamily)?.id
      || String(data.actionFamily || 'idle').toLowerCase();
    actor.dataset.animationState = animStateId;
    this._armSemanticActionWatchdog(run, actionId, data.actionFamily);

    const active = () => this._semanticActionRuns.get(actionId) === run;
    const showVisualContact = (index, at = performance.now()) => {
      if (run.visualContactShown || index < run.impactFrameIndex) return;
      run.visualContactShown = true;
      this.stagePresenter?.visualContact?.(actionId, at);
      eventBus.emit('combat:visualContact', { ...data, visualContactAt: at });
    };
    const fallback = reason => {
      if (!active()) return;
      console.warn('[combat-anim] action frames unavailable', animation.frameSetId, reason);
      overlay.remove();
      if (reason === 'missing_action_scale_binding') {
        actor.dataset.actionCarrierMetricStatus = 'missing-scale-binding';
      }
      const startedAt = performance.now();
      this.stagePresenter?.resume?.(actionId, startedAt);
      eventBus.emit('combat:visualActionStarted', { ...data, visualStartAt: startedAt, mediaFallback: true });
      const impactDelay = Math.max(0, Number(data.stage?.impactAtMs) || 0);
      run.timeouts.push(setTimeout(() => {
        if (this._semanticActionRuns.get(actionId) !== run) return;
        showVisualContact(run.impactFrameIndex);
        if (!run.visualImpactShown) {
          this._showSemanticImpact({ ...(run.pendingImpactData || data), mediaFallback: true });
          run.visualImpactShown = true;
        }
      }, impactDelay));
      const hold = Math.min(650, Math.max(impactDelay + 80, Number(data.duration) || 0, 160));
      run.timeouts.push(setTimeout(() => this._clearSemanticAction(actionId, {
        visualLifecycleCompleted: true
      }), hold));
    };
    const impactFrameIndex = Number(animation.impactFrameIndex);
    const resolvedImpactIndex = Number.isFinite(impactFrameIndex)
      && impactFrameIndex > 0 && impactFrameIndex < frames.length
      ? impactFrameIndex
      : (frames.length >= 3 ? Math.floor(frames.length / 2) : -1);
    run.impactFrameIndex = Math.max(0, resolvedImpactIndex);
    if (data._queuedImpactData) this._onSemanticImpact(data._queuedImpactData);
    const hitstopMs = resolvedImpactIndex > 0 ? this._resolveImpactHitstop(data, animation) : 0;
    const fallbackBeat = Math.max(16, Math.floor((Number(data.duration) || 1) / frames.length));
    const authoredBeats = frames.map((_, index) => frameDurations[index] || fallbackBeat);
    const visualDuration = this._resolveSemanticActionVisualDuration(data, authoredBeats, 1);
    const contactHold = Number(animation.contactHoldMs);
    const authoredContactHold = Number.isFinite(contactHold) && contactHold >= 20 && contactHold <= 40;
    const holds = authoredBeats.map((beat, index) => index === resolvedImpactIndex
      ? (authoredContactHold ? contactHold : beat + hitstopMs)
      : index === resolvedImpactIndex + 1 && !authoredContactHold
        ? Math.max(16, beat - hitstopMs) : beat);
    const beforeLast = holds.slice(0, -1).reduce((sum, value) => sum + value, 0);
    holds[holds.length - 1] = Math.max(holds.at(-1), visualDuration - beforeLast) + 32;

    if (data.source === 'player' && animation.visualStageId === 'S1_outer_novice'
      && ['attack', 'skill', 'guard'].includes(String(data.actionFamily || ''))
      && !matchedCanvas) {
      fallback('missing_action_scale_binding');
      return 'started';
    }

    const startVisualClock = startedAt => {
      if (!active()) return;
      run.currentFrameIndex = 0;
      actor.classList.add('is-semantic-action-active');
      actorContainer?.classList.add('is-semantic-action-active');
      overlay.classList.add('is-frame-ready');
      overlay.dataset.visualStartAt = String(startedAt);
      this.stagePresenter?.resume?.(actionId, startedAt);
      eventBus.emit('combat:visualActionStarted', { ...data, visualStartAt: startedAt });
      if (!run.projectileImpact) showVisualContact(0, startedAt);
      if (!run.projectileImpact && run.impactFrameIndex === 0
        && run.pendingImpactData && !run.visualImpactShown) {
        this._showSemanticImpact(run.pendingImpactData);
        run.visualImpactShown = true;
      }
      let index = 0;
      let nextAt = startedAt + holds[0];
      let contactPaintFrames = 0;
      const tick = now => {
        if (!active()) return;
        if (index === resolvedImpactIndex && contactPaintFrames++ < 1) {
          run.animationFrames.push(requestAnimationFrame(tick));
          return;
        }
        if (now >= nextAt) {
          if (index === frames.length - 1) {
            this._clearSemanticAction(actionId, { visualLifecycleCompleted: true });
            return;
          }
          index += 1;
          if (index === resolvedImpactIndex) contactPaintFrames = 0;
          run.currentFrameIndex = index;
          applyActionFrameMetric(index);
          overlay.src = frames[index];
          overlay.dataset.frameIndex = String(frameMetricIndices[index]);
          if (!run.projectileImpact) showVisualContact(index, now);
          if (!run.projectileImpact && run.pendingImpactData && !run.visualImpactShown
            && index >= run.impactFrameIndex) {
            this._showSemanticImpact(run.pendingImpactData);
            run.visualImpactShown = true;
          }
          const minimumVisibleHold = index === resolvedImpactIndex
            ? holds[index] : Math.min(holds[index], 50);
          nextAt = Math.max(nextAt + holds[index], performance.now() + minimumVisibleHold);
        }
        run.animationFrames.push(requestAnimationFrame(tick));
      };
      if (typeof requestAnimationFrame === 'function' && document.visibilityState !== 'hidden') {
        run.animationFrames.push(requestAnimationFrame(tick));
      } else {
        let elapsed = 0;
        holds.forEach((hold, frameIndex) => {
          elapsed += hold;
          run.timeouts.push(setTimeout(() => {
            if (!active()) return;
            if (frameIndex === frames.length - 1) {
              this._clearSemanticAction(actionId, { visualLifecycleCompleted: true });
            } else {
              const next = frameIndex + 1;
              run.currentFrameIndex = next;
              applyActionFrameMetric(next);
              overlay.src = frames[next];
              overlay.dataset.frameIndex = String(frameMetricIndices[next]);
              if (!run.projectileImpact) showVisualContact(next);
              if (!run.projectileImpact && run.pendingImpactData && !run.visualImpactShown
                && next >= run.impactFrameIndex) {
                this._showSemanticImpact(run.pendingImpactData);
                run.visualImpactShown = true;
              }
            }
          }, elapsed));
        });
      }
    };
    this._awaitDecodedActionFrames(frames, 1200, actionId).then(ready => {
      if (!active()) return;
      if (!ready) return fallback('predecode_timeout_or_failure');
      overlay.src = frames[0];
      actor.appendChild(overlay);
      const reveal = async () => {
        if (!active() || !overlay.isConnected) return;
        let timeout = null;
        const firstFrameReady = typeof overlay.decode === 'function'
          ? overlay.decode().then(() => true, () => false)
          : new Promise(resolve => {
            if (overlay.complete) return resolve(overlay.naturalWidth > 0);
            overlay.addEventListener('load', () => resolve(true), { once: true });
            overlay.addEventListener('error', () => resolve(false), { once: true });
          });
        const decoded = await Promise.race([
          firstFrameReady,
          // A routed image can require a fresh fetch even after the sequence
          // preload decoded it. Give that mounted first frame the same bounded
          // decode window as the authored sequence before using the fallback.
          new Promise(resolve => { timeout = setTimeout(() => resolve(false), 1200); })
        ]);
        clearTimeout(timeout);
        if (!active() || !overlay.isConnected) return;
        if (decoded && overlay.complete && overlay.naturalWidth > 0) startVisualClock(performance.now());
        else fallback('first_frame_not_ready');
      };
      if (typeof requestAnimationFrame === 'function' && document.visibilityState !== 'hidden') {
        run.animationFrames.push(requestAnimationFrame(reveal));
      } else {
        reveal();
      }
    });
    return 'started';
  }

  _isPlayerSequenceCompatibleWithDisplayedStage(animation = {}, data = {}) {
    const renderedStageId = this._currentContext?.displayedVisualStageId || null;
    const eventStageId = data.displayedVisualStageId || animation.displayedVisualStageId || null;
    const stageId = eventStageId || renderedStageId;
    if (!stageId || (renderedStageId && eventStageId && renderedStageId !== eventStageId)) return false;
    return Array.isArray(animation.compatibleStageIds)
      && animation.compatibleStageIds.includes(stageId);
  }

  _onSemanticImpact(data = {}) {
    const actionId = String(data.actionId || '');
    const queued = [...this._semanticPresentationQueues.values()]
      .flat().find(item => String(item.actionId || '') === actionId);
    if (queued) {
      queued._queuedImpactData = data;
      return;
    }
    const run = this._semanticActionRuns.get(actionId);
    if (run?.overlay && !run.visualImpactShown) {
      run.pendingImpactData = data;
      if (run.projectileImpact) {
        if (run.projectileImpactQueued) return;
        run.projectileImpactQueued = true;
        const arrive = () => {
          if (this._semanticActionRuns.get(String(data.actionId || '')) !== run || run.visualImpactShown) return;
          run.visualImpactShown = true;
          this.stagePresenter?.visualContact?.(data.actionId, performance.now());
          eventBus.emit('combat:visualContact', data);
          this._showSemanticImpact(data);
        };
        if (!this.stagePresenter?.scheduleAtImpact?.(data.actionId, arrive)) {
          const delay = Math.max(0, Number(data.stage?.impactAtMs) || 0);
          run.timeouts.push(setTimeout(arrive, delay));
        }
        return;
      }
      if (run.currentFrameIndex < Number(run.impactFrameIndex)) return;
      run.visualImpactShown = true;
    }
    this._showSemanticImpact(data);
  }

  _showSemanticImpact(data = {}) {
    const target = data.target === 'player' ? this.playerSprite : this.enemySprite;
    if (!target) return;
    target.dataset.lastImpactActionId = String(data.actionId || '');
    target.classList.remove('is-semantic-impact');
    void target.offsetWidth;
    target.classList.add('is-semantic-impact');
    // Recoil and stage shake ride on the presenter, which owns the exchange
    // geometry.  The hitstop itself lives on the frame clock in
    // _startSemanticActionFrameRun.
    if (data.actionId) {
      this.stagePresenter?.applyImpactWeightByActionId(data.actionId, {
        contact: data.contact || data.stage?.contact || null
      });
    }
    eventBus.emit('combat:visualImpact', data);
  }

  _onSemanticActionCompleted(data = {}) {
    const actor = data.source === 'enemy' ? this.enemySprite : this.playerSprite;
    const actorContainer = actor?.closest('.enemy-area, .player-area');
    const actionId = String(data.actionId || '');
    this.stagePresenter?.complete(data);
    const run = this._semanticActionRuns.get(actionId);
    if (run && !data.interrupted) {
      run.completed = true;
      return;
    }
    if (data.interrupted) {
      this._semanticPresentationQueues.delete(actor);
      this._pendingVfxByActionId.delete(actionId);
    }
    this._clearSemanticAction(actionId, { drainPresentationQueue: !data.interrupted });
    if (actor?.dataset.combatActionId === String(data.actionId || '')) {
      actor.classList.remove('is-semantic-action-active');
      actorContainer?.classList.remove('is-semantic-action-active');
      delete actor.dataset.combatActionId;
      delete actor.dataset.combatActionFamily;
      delete actor.dataset.actionCarrierMetricStatus;
    }
    if (this.actionLayer?.dataset.activeActionId === String(data.actionId || '')) {
      delete this.actionLayer.dataset.activeActionId;
    }
    this._reflowPathSynergyCues();
  }

  _enqueueSemanticPresentation(actor, data = {}) {
    if (!actor || !data?.actionId) return;
    const queue = this._semanticPresentationQueues.get(actor) || [];
    const animation = data.animation || {};
    this._semanticPresentationOrder = Number.isFinite(this._semanticPresentationOrder)
      ? this._semanticPresentationOrder + 1 : 1;
    queue.push({
      ...data,
      _presentationOrder: this._semanticPresentationOrder,
      animation: {
        ...animation,
        frames: Array.isArray(animation.frames) ? [...animation.frames] : animation.frames,
        frameDurations: Array.isArray(animation.frameDurations) ? [...animation.frameDurations] : animation.frameDurations
      }
    });
    this._semanticPresentationQueues.set(actor, queue);
  }

  _drainSemanticPresentationQueue(actor) {
    const serializedExchange = this.container?.dataset?.exchangeChoreographyPolicyId
      === 'serialized_active_body_v1';
    // A rejected carrier owns neither a visual clock nor a completion callback.
    // Consume that skip synchronously, preserving FIFO, until a real lifecycle
    // owns progress again. Never skip a mounted body or a terminal fallback.
    while (true) {
      if (serializedExchange && this._semanticActionRuns.size > 0) return;
      let selected = null;
      if (serializedExchange) {
        // Cross-actor bodies follow the global authoritative event order,
        // rather than preferring the actor whose preceding run just cleared.
        for (const [candidate, queue] of this._semanticPresentationQueues.entries()) {
          const next = queue?.[0];
          if (!next) continue;
          if (!selected || Number(next._presentationOrder) < Number(selected.next._presentationOrder)) {
            selected = { candidate, queue, next };
          }
        }
      } else {
        const candidates = actor
          ? [actor, ...[...this._semanticPresentationQueues.keys()].filter(candidate => candidate !== actor)]
          : [...this._semanticPresentationQueues.keys()];
        for (const candidate of candidates) {
          if (!candidate || [...this._semanticActionRuns.values()].some(run => run.actor === candidate)) continue;
          const queue = this._semanticPresentationQueues.get(candidate);
          const next = queue?.[0];
          if (!next) {
            this._semanticPresentationQueues.delete(candidate);
            continue;
          }
          selected = { candidate, queue, next };
          break;
        }
      }
      if (!selected) return;
      selected.queue.shift();
      if (!selected.queue.length) this._semanticPresentationQueues.delete(selected.candidate);
      const disposition = this._onSemanticActionStarted({ ...selected.next, _presentationDequeued: true });
      if (disposition !== 'skipped') return;
    }
  }

  // ── 战斗动画状态机（T-01/T-02）───────────────────────────────────────────
  // 权威源是 data/combat/animation_state_machine.json（经 sync_inline_data.js
  // 内联为 DATA_MODULES['combat:animation_state_machine']）。时长与缓动一律从
  // 契约读，代码里不写第二份数字。取不到时降级为 null，绝不阻断战斗。
  _animationStateMachine() {
    if (this._animationStateMachineCache !== undefined) return this._animationStateMachineCache;
    let contract = null;
    try {
      const inline = (typeof DATA_MODULES !== 'undefined') ? DATA_MODULES : null;
      const raw = inline ? inline['combat:animation_state_machine'] : null;
      if (raw && raw.contractId === 'combat_animation_state_machine_v1' && Array.isArray(raw.states)) contract = raw;
    } catch (_error) {
      contract = null;
    }
    this._animationStateMachineCache = contract;
    return contract;
  }

  _animationStateFor(actionFamily) {
    const machine = this._animationStateMachine();
    if (!machine) return null;
    const id = String(actionFamily || '').toLowerCase();
    // 动作族与状态 id 同名（attack/skill/guard/hurt/defeat）；reaction 归入 guard 守势，
    // victory 单列；未知族按契约 unknownStatePolicy 回落 idle。
    const alias = { reaction: 'guard', followthrough: 'attack' };
    const stateId = alias[id] || id;
    return machine.states.find(state => state.id === stateId) || null;
  }

  // 看门狗：任一状态超过契约 watchdogMs 仍未完成，强制回落 idle，杜绝状态卡死。
  // 只在 run 未完成且未收到 completed 时才生效；终结态（defeat/victory）只做
  // 残留 DOM 清理，不做状态回落，避免把死亡演出打断。
  _armSemanticActionWatchdog(run, actionId, actionFamily) {
    const state = this._animationStateFor(actionFamily);
    if (!state || !Number.isFinite(state.watchdogMs) || state.watchdogMs <= 0) return;
    const grace = Number(this._animationStateMachine()?.globalRules?.watchdogGraceMs) || 800;
    run.watchdog = setTimeout(() => {
      const active = this._semanticActionRuns.get(String(actionId));
      if (!active || active !== run) return;
      if (run.completed) return;
      console.warn('[combat-anim] watchdog fired, forcing idle:', String(actionFamily || ''), state.watchdogMs + grace, 'ms');
      this._clearSemanticAction(actionId, { drainPresentationQueue: false });
      this._forceIdleActor(run.actor);
    }, state.watchdogMs + grace);
  }

  // 按 data/combat/animation_state_machine.json 裁决"新动作能否打断当前动作"。
  // 返回 'interrupt' | 'allow' | 'queue'：
  //   interrupt —— 新动作优先级更高且当前状态显式允许被它打断 → 立即清旧演出
  //   queue     —— 优先级不高于当前 → 交回既有排队
  //   allow     —— 契约缺失/无在播动作/契约未列出该打断关系 → **不干预既有逻辑**
  // 最后一条是安全阀：契约里没写的关系一律不擅自打断，避免改坏既有序列化编排。
  _resolveStateMachineInterrupt(actor, data = {}) {
    if (!actor) return 'allow';
    const incoming = this._animationStateFor(data.actionFamily);
    if (!incoming) return 'allow';
    const currentRun = [...this._semanticActionRuns.values()].find(run => run.actor === actor);
    if (!currentRun || currentRun.completed) return 'allow';
    const current = this._animationStateFor(currentRun.actionFamily);
    if (!current) return 'allow';
    const inPriority = Number(incoming.interruptPriority);
    const curPriority = Number(current.interruptPriority);
    if (!Number.isFinite(inPriority) || !Number.isFinite(curPriority)) return 'allow';
    if (inPriority <= curPriority) return 'queue';
    if (!Array.isArray(current.canInterruptBy) || !current.canInterruptBy.includes(incoming.id)) return 'allow';
    return 'interrupt';
  }

  _forceIdleActor(actor) {
    if (!actor) return;
    actor.classList.remove('is-semantic-action-active', 'is-semantic-impact');
    actor.closest?.('.enemy-area, .player-area')?.classList.remove('is-semantic-action-active');
    delete actor.dataset.combatActionId;
    delete actor.dataset.combatActionFamily;
    delete actor.dataset.actionCarrierMetricStatus;
    actor.dataset.animationState = 'idle';
    actor.dataset.animationStateRecovery = 'watchdog';
    this._semanticPresentationQueues.delete(actor);
    this._reflowPathSynergyCues();
  }

  _clearSemanticAction(actionId, {
    drainPresentationQueue = true,
    visualLifecycleCompleted = false
  } = {}) {
    const stableId = String(actionId || '');
    this._pendingVfxDecodeByActionId.delete(stableId);
    this._suppressedVfxActionIds.delete(stableId);
    const run = this._semanticActionRuns.get(stableId);
    const actor = run?.actor || null;
    if (run) {
      for (const timeout of run.timeouts || []) clearTimeout(timeout);
      if (run.watchdog) clearTimeout(run.watchdog);
      if (typeof cancelAnimationFrame === 'function') {
        for (const frame of run.animationFrames || []) cancelAnimationFrame(frame);
      }
      this.stagePresenter?.clear?.(stableId);
      const retainTerminalActorState = run.terminalActorState === true
        && visualLifecycleCompleted
        && run.overlay?.isConnected;
      const retainReactionPose = run.presentationOnly === true
        && run.actionFamily === 'reaction'
        && visualLifecycleCompleted
        && run.overlay?.isConnected
        // The combat resolver and the presentation queue are intentionally
        // decoupled.  Depending on the browser task boundary, the enemy
        // follow-through may be queued just before or just after this reaction
        // reaches its last frame.  Retain that reviewed final pose either way;
        // the next player action or completion of the authoritative enemy
        // action clears it below, so this cannot leak into a later exchange.
        ;
      if (retainTerminalActorState) {
        this._clearTerminalActorResidue(run.actor);
        run.overlay.classList.add('is-terminal-actor-state');
        run.overlay.dataset.terminalActorState = 'true';
        run.actor.dataset.terminalActorState = 'true';
        this._terminalActorResidues.set(run.actor, run.overlay);
      } else if (retainReactionPose) {
        this._clearReactionActorResidue(run.actor);
        run.overlay.classList.add('is-reaction-actor-state');
        run.overlay.dataset.reactionActorState = 'true';
        run.actor.dataset.reactionActorState = 'true';
        this._reactionActorResidues.set(run.actor, run.overlay);
      } else {
        run.overlay?.remove();
      }
      if (run.actor?.dataset.combatActionId === stableId) {
        run.actor.classList.remove('is-semantic-action-active');
        run.actorContainer?.classList.remove('is-semantic-action-active');
        delete run.actor.dataset.combatActionId;
        delete run.actor.dataset.combatActionFamily;
        delete run.actor.dataset.actionCarrierMetricStatus;
      }
      this._semanticActionRuns.delete(stableId);
      if (run.locksPlayerInput) eventBus.emit('combat:visualActionUnmounted', { actionId: stableId });
      // A preceding player attack can finish after the chosen reaction pose has
      // already reached its held frame.  Clearing on *any* authoritative body
      // completion erased that defence one task before the queued enemy strike.
      // The held reaction belongs to the enemy follow-through window: clear it
      // when that enemy action completes (or when the player starts a new pose),
      // not when an older player action happens to leave the queue.
      if (run.presentationOnly !== true && run.actor === this.enemySprite) {
        this._clearAllReactionActorResidues();
      }
    }
    if (this.actionLayer?.dataset.activeActionId === stableId) {
      delete this.actionLayer.dataset.activeActionId;
    }
    if (run?.terminal === true && visualLifecycleCompleted) {
      this._semanticPresentationQueues.clear();
      eventBus.emit('ui:hideCombatScreen', {
        terminalPresentation: true,
        actionId: stableId,
        frameSetId: run.frameSetId || null,
        visualLifecycleCompleted: true
      });
    } else if (drainPresentationQueue) {
      this._drainSemanticPresentationQueue(actor);
    }
    this._reflowPathSynergyCues();
  }

  _clearSemanticActionsForActor(actor, { discardPresentationQueue = true } = {}) {
    if (discardPresentationQueue) this._semanticPresentationQueues.delete(actor);
    this._clearTerminalActorResidue(actor);
    this._clearReactionActorResidue(actor);
    for (const [actionId, run] of this._semanticActionRuns.entries()) {
      if (run.actor === actor) this._clearSemanticAction(actionId, { drainPresentationQueue: false });
    }
  }

  _clearTerminalActorResidue(actor) {
    const residue = actor ? this._terminalActorResidues.get(actor) : null;
    residue?.remove();
    if (actor) {
      delete actor.dataset.terminalActorState;
      this._terminalActorResidues.delete(actor);
    }
  }

  _clearReactionActorResidue(actor) {
    const residue = actor ? this._reactionActorResidues?.get(actor) : null;
    residue?.remove();
    if (actor?.dataset) {
      delete actor.dataset.reactionActorState;
    }
    if (actor) this._reactionActorResidues?.delete(actor);
  }

  _clearAllReactionActorResidues() {
    if (!this._reactionActorResidues) return;
    for (const actor of [...this._reactionActorResidues.keys()]) {
      this._clearReactionActorResidue(actor);
    }
  }

  _clearAllSemanticActions() {
    this._clearPathSynergyCues();
    this._semanticPresentationQueues.clear();
    this._pendingVfxByActionId.clear();
    this._pendingVfxDecodeByActionId.clear();
    this._suppressedVfxActionIds.clear();
    this._clearAllReactionActorResidues();
    for (const actionId of [...this._semanticActionRuns.keys()]) {
      this._clearSemanticAction(actionId, { drainPresentationQueue: false });
    }
    for (const actor of [...this._terminalActorResidues.keys()]) {
      this._clearTerminalActorResidue(actor);
    }
  }

  _preloadBossPhaseTransitionFrames(transition = null) {
    const animation = transition?.animation;
    if (animation?.kind !== 'frame_sequence' || animation?.motionApproved !== true) return;
    this._preloadImageSources(animation.frames || []);
  }

  _clearBossPhasePresentations({ resetSeen = false } = {}) {
    for (const run of this._bossPhasePresentationRuns.values()) {
      for (const timeout of run.timeouts || []) clearTimeout(timeout);
      if (typeof cancelAnimationFrame === 'function') {
        for (const frame of run.animationFrames || []) cancelAnimationFrame(frame);
      }
      run.node?.remove();
    }
    this._bossPhasePresentationRuns.clear();
    if (resetSeen) this._seenBossPhaseEventIds.clear();
  }

  _onBossPhaseChanged(data = {}) {
    const transition = data?.phaseTransition;
    const animation = transition?.animation;
    const sourceCardId = String(data?.sourceCardId || '');
    const eventId = String(transition?.eventId || '');
    const frames = Array.isArray(animation?.frames)
      ? animation.frames.filter(frame => typeof frame === 'string' && frame.trim())
      : [];
    const frameDurations = Array.isArray(animation?.frameDurations)
      ? animation.frameDurations.map(duration => Math.max(16, Number(duration) || 0))
      : [];
    const current = Math.floor(Number(data?.current) || 0);
    const total = Math.floor(Number(data?.total) || 0);
    // This is intentionally strict. A globally emitted event from a stale or
    // foreign combat must not paint a transition over the active battlefield.
    if (!this._isActive()
      || !this.container
      || !sourceCardId
      || this._currentContext?.cardId !== sourceCardId
      || transition?.sourceCardId !== sourceCardId
      || !eventId.startsWith('boss-phase:')
      || this._seenBossPhaseEventIds.has(eventId)
      || animation?.kind !== 'frame_sequence'
      || animation?.motionApproved !== true
      || animation?.frameSetId !== transition?.frameSetId
      || frames.length < 2
      || frameDurations.length !== frames.length
      || frameDurations.some(duration => !Number.isFinite(duration) || duration < 16)
      || current < 2
      || total < current
      || Number(transition.current) !== current
      || Number(transition.total) !== total) return false;

    this._seenBossPhaseEventIds.add(eventId);
    const cue = transition.phaseCue || {};
    const headline = String(cue.headline || data?.phase?.name || `第 ${current} 相`);
    const detail = String(cue.detail || transition.label || '阵势重构，敌策已变');
    const node = document.createElement('section');
    node.className = 'combat-boss-phase-transition';
    node.dataset.phaseEventId = eventId;
    node.dataset.frameSetId = String(transition.frameSetId);
    node.dataset.current = String(current);
    node.dataset.total = String(total);
    node.setAttribute('role', 'status');
    node.setAttribute('aria-live', 'polite');

    const copy = document.createElement('div');
    copy.className = 'combat-boss-phase-copy';
    const kicker = document.createElement('small');
    kicker.textContent = transition.label || '首领转相';
    const title = document.createElement('strong');
    title.textContent = headline;
    const description = document.createElement('span');
    description.textContent = detail;
    copy.append(kicker, title, description);
    node.appendChild(copy);

    let frame = null;
    if (!this._reducedMotion) {
      frame = document.createElement('img');
      frame.className = 'combat-boss-phase-frame';
      frame.alt = '';
      frame.draggable = false;
      frame.setAttribute('aria-hidden', 'true');
      frame.dataset.frameIndex = '0';
      frame.src = frames[0];
      node.prepend(frame);
    } else {
      node.classList.add('is-reduced-motion');
    }

    this.container.appendChild(node);
    this.container.dataset.lastBossPhaseEventId = eventId;
    this.container.dataset.lastBossPhaseFrameSetId = String(transition.frameSetId);
    this._announceCombatLive(`${headline}：${detail}`, {
      kind: 'boss',
      durationMs: 3600
    });

    const run = { node, timeouts: [], animationFrames: [] };
    this._bossPhasePresentationRuns.set(eventId, run);
    const finish = () => {
      const activeRun = this._bossPhasePresentationRuns.get(eventId);
      if (!activeRun || activeRun !== run) return;
      node.classList.remove('visible');
      const remove = setTimeout(() => {
        if (this._bossPhasePresentationRuns.get(eventId) !== run) return;
        node.remove();
        this._bossPhasePresentationRuns.delete(eventId);
      }, this._reducedMotion ? 10 : 150);
      run.timeouts.push(remove);
    };
    const start = () => {
      if (!node.isConnected) return;
      node.classList.add('visible');
      if (!this._reducedMotion && frame) {
        let elapsed = 0;
        for (let index = 1; index < frames.length; index += 1) {
          elapsed += frameDurations[index - 1];
          const timeout = setTimeout(() => {
            if (this._bossPhasePresentationRuns.get(eventId) !== run || !frame.isConnected) return;
            frame.dataset.frameIndex = String(index);
            frame.src = frames[index];
          }, elapsed);
          run.timeouts.push(timeout);
        }
        const complete = setTimeout(finish, Math.max(Number(transition.duration) || 0, elapsed + frameDurations.at(-1)));
        run.timeouts.push(complete);
      } else {
        const complete = setTimeout(finish, 1100);
        run.timeouts.push(complete);
      }
    };
    if (typeof requestAnimationFrame === 'function') {
      run.animationFrames.push(requestAnimationFrame(() => {
        run.animationFrames.push(requestAnimationFrame(start));
      }));
    } else {
      start();
    }
    return true;
  }

  _preloadSemanticActionFrames(animations = []) {
    if (!Array.isArray(animations)) return;
    const sources = [];
    for (const animation of animations) {
      if (animation?.kind !== 'frame_sequence' || animation.motionApproved !== true) continue;
      for (const source of animation.frames || []) {
        if (typeof source !== 'string' || !source.trim() || this._preloadedSemanticFrames.has(source)) continue;
        this._preloadedSemanticFrames.add(source);
        sources.push(source);
      }
    }
    this._preloadImageSources(sources);
    const primeNext = index => {
      if (index >= sources.length) return;
      const run = () => {
        if (this._semanticActionRuns.size > 0) {
          setTimeout(() => primeNext(index), 100);
          return;
        }
        this._decodePreloadedImage(sources[index]).then(() => primeNext(index + 1));
      };
      if (typeof requestIdleCallback === 'function') requestIdleCallback(run);
      else setTimeout(run, 0);
    };
    primeNext(0);
  }

  _preloadActorPortraitFrames(actor = {}) {
    if (!actor || typeof actor !== 'object') return;
    this._preloadImageSources([
      actor.image,
      ...Object.values(actor.intentFrames || {})
    ]);
  }

  _preloadImageSources(sources = []) {
    if (typeof Image === 'undefined' || !Array.isArray(sources)) return;
    for (const rawSource of sources) {
      const source = typeof rawSource === 'string' ? rawSource.trim() : '';
      if (!source || this._preloadedImages.has(source)) continue;
      const image = new Image();
      image.decoding = 'async';
      image.src = source;
      this._preloadedImages.set(source, { image, decoded: null });
    }
  }

  _decodePreloadedImage(source) {
    const record = this._preloadedImages.get(source);
    if (!record) return Promise.resolve(false);
    if (!record.decoded) {
      const image = record.image;
      const decode = typeof image.decode === 'function'
        ? image.decode().then(() => image.naturalWidth > 0, () => false)
        : new Promise(resolve => {
          if (image.complete) return resolve(image.naturalWidth > 0);
          image.addEventListener('load', () => resolve(image.naturalWidth > 0), { once: true });
          image.addEventListener('error', () => resolve(false), { once: true });
        });
      record.decoded = decode.then(ready => {
        // A transient request failure must not poison later actions that use
        // the same authored frame after the browser can fetch it again.
        if (!ready && this._preloadedImages.get(source) === record) this._preloadedImages.delete(source);
        return ready;
      });
    }
    return record.decoded;
  }

  async _awaitDecodedActionFrames(frames = [], timeoutMs = 750, actionId = null) {
    this._preloadImageSources(frames);
    if (!frames.length) return false;
    let timeout = null;
    let fxTimeout = null;
    let bodyReady = null;
    let fxReady = null;
    try {
      const body = Promise.all(frames.map(frame => this._decodePreloadedImage(frame)))
        .then(ready => { bodyReady = ready.every(Boolean); });
      await Promise.resolve();
      const vfx = this._pendingVfxDecodeByActionId.get(String(actionId || '')) || [];
      const fx = Promise.all(vfx).then(ready => { fxReady = ready.every(Boolean); });
      const boundedFx = vfx.length ? Promise.race([
        fx,
        new Promise(resolve => { fxTimeout = setTimeout(() => { fxReady = false; resolve(); }, 750); })
      ]) : fx;
      await Promise.race([
        Promise.all([body, boundedFx]),
        new Promise(resolve => { timeout = setTimeout(resolve, timeoutMs); })
      ]);
      if (bodyReady !== true) return false;
      if (fxReady !== true && vfx.length) {
        this._suppressedVfxActionIds.add(String(actionId || ''));
        if (this.container) this.container.dataset.lastFxStatus = 'rejected_first_frame_decode_failure';
      }
      return true;
    } finally {
      clearTimeout(timeout);
      clearTimeout(fxTimeout);
    }
  }

  _announceReactionResult(data = {}) {
    const labels = {
      guarded: '格挡成功，攻势被削弱。',
      deflected: '偏斩成功，敌方露出破绽。',
      interrupted: '截术成功，敌方行动被取消。',
      disrupted: '截术成功，敌方攻击被扰乱。',
      absorbed: '硬承成功，余威化为反击劲。',
      transmuted_status: '逆炼成功，负面术式化为丹毒。',
      transmuted_damage: '逆炼成功，伤害被削弱并反炼。',
      evaded: '闪避成功；下一回合少抽一张牌。',
      missed: '未及时反应，完整承受敌方行动。',
      taken: '你保留余力，完整承受敌方行动。'
    };
    this._announceCombatLive(
      `${labels[data.result] || '反应已结算'} 实际受到 ${Math.max(0, Number(data.damageTaken) || 0)} 点伤害。`,
      { kind: 'result', durationMs: 2800 }
    );
  }

  _announcePlanTransition(data = {}) {
    // Plan IDs such as PRESSURE are engine authority, never player-facing
    // copy. Live plan events carry authored labels; stale/foreign events use
    // neutral Chinese fallbacks rather than leaking implementation keys.
    const from = String(data.fromLabel || '').trim() || '前势';
    const to = String(data.toLabel || '').trim() || '变势';
    this._announceCombatLive(
      `敌策转势 · ${this._planCauseCompactLabel(data.cause)}\n${from} → ${to}`,
      { kind: 'plan', durationMs: 2600 }
    );
  }

  _planCauseCompactLabel(cause) {
    const labels = {
      player_overcommitted: '真元耗尽',
      repeated_card_type: '招式重复',
      player_reserved_resource: '留力被察',
      deflected: '偏斩失衡',
      transmuted: '逆炼破势',
      action_resolved: '旧势已尽'
    };
    return labels[cause] || '战术变化';
  }

  _announceCombatLive(message, options = {}) {
    if (!this.reactionLive) return;
    this._clearCombatLive({ clearText: false });
    const text = String(message || '').trim();
    if (!text) {
      this._clearCombatLive();
      return;
    }
    const kind = ['plan', 'result', 'boss'].includes(options.kind) ? options.kind : 'result';
    const durationMs = Math.max(1200, Number(options.durationMs) || 2600);
    this.reactionLive.dataset.liveKind = kind;
    this.reactionLive.textContent = text;
    this.reactionLive.classList.add('is-visible');
    this._combatLiveTimer = setTimeout(() => {
      if (this.reactionLive?.textContent === text) this._clearCombatLive();
    }, durationMs);
  }

  _clearCombatLive(options = {}) {
    if (this._combatLiveTimer) clearTimeout(this._combatLiveTimer);
    this._combatLiveTimer = null;
    if (!this.reactionLive) return;
    this.reactionLive.classList.remove('is-visible');
    delete this.reactionLive.dataset.liveKind;
    if (options.clearText !== false) this.reactionLive.textContent = '';
  }

  _planCauseLabel(cause) {
    const labels = {
      player_overcommitted: '你连续耗尽真元',
      repeated_card_type: '敌人看破重复招式',
      player_reserved_resource: '敌人察觉你正在留力',
      deflected: '偏斩使敌势失衡',
      transmuted: '逆炼改写敌势',
      action_resolved: '上一段敌策已经执行'
    };
    return labels[cause] || '战术发生变化';
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

  buildCardViewModel(card, index, context = {}) {
    const tags = Array.isArray(card.tags) ? card.tags : [];
    const validPaths = ['spell', 'sword', 'body', 'pill'];
    const taggedPath = validPaths.find(path => tags.includes(path)) || '';
    const playerPath = validPaths.includes(context.playerPath) ? context.playerPath : '';
    const cardPath = taggedPath || playerPath;
    const dynamicProvenance = context?.cardProvenance?.[card.id] || null;
    const statusNames = {
      vulnerable: '破绽',
      opening: '破绽',
      weak: '虚弱',
      poison: '丹毒',
      fortify: '金刚劲',
      aura: '罡气',
      sword_intent: '剑意',
      spell_seal: '法印'
    };
    const effectNames = {
      damage: '伤害',
      block: '护盾',
      heal: '疗愈',
      gain_qi: '回元',
      draw: '抽牌',
      weaken: '削弱',
      backlash: '反噬',
      self_damage: '自伤',
      draw_per_turn: '每回合抽牌',
      draw_per_status: '按状态抽牌'
    };
    const statusAliases = {
      swordIntent: 'sword_intent',
      spellSeal: 'spell_seal'
    };

    const effects = (Array.isArray(card.effects) ? card.effects : []).map(effect => {
      const rawStatus = effect.statusId || effect.statusType || 'status';
      const normalizedStatus = statusAliases[rawStatus] || rawStatus;
      const kind = effect.type === 'status'
        ? normalizedStatus
        : (effect.type || 'effect');
      const label = effect.type === 'status'
        ? (statusNames[kind] || '状态')
        : (effectNames[effect.type] || '特殊');
      const targetsEnemy = effect.target === 'enemy'
        || ['damage', 'weaken'].includes(effect.type);
      const target = targetsEnemy ? '敌方' : '自身';
      const numericValue = Number(effect.value);
      const effectBonus = Math.max(0, Number(dynamicProvenance?.effectBonuses?.[effect.type]) || 0);
      const value = Number.isFinite(numericValue)
        ? (effectBonus > 0 ? `${numericValue}+${effectBonus}` : numericValue)
        : (effect.statusId ? (statusNames[effect.statusId] || effect.statusId) : '条件');
      return { kind, label, value, target };
    });

    let source = '游历所得';
    let rarity = '术式';
    if (tags.includes('basic')) {
      source = '基础招式';
      rarity = '凡式';
    } else if (tags.includes('opportunity') && tags.includes('bandit')) {
      source = '女匪寨机缘';
      rarity = '机缘';
    } else if (tags.includes('legacy')) {
      source = '传承残卷';
      rarity = '传承';
    } else if (tags.includes('equipment')) {
      source = '装备术式';
      rarity = '器式';
    } else if (tags.includes('treasure')) {
      source = '法宝术式';
      rarity = '珍式';
    } else {
      const pathSources = {
        spell: '法修术式',
        sword: '剑修术式',
        body: '体修术式',
        pill: '丹修术式'
      };
      if (taggedPath) {
        source = pathSources[taggedPath];
        rarity = taggedPath === context.playerPath ? '本道' : '旁修';
      }
    }
    if (dynamicProvenance) {
      source = dynamicProvenance.source || source;
      rarity = dynamicProvenance.rarity || rarity;
    }

    let role = card.type === 'attack' ? '攻势' : (card.type === 'power' ? '运势' : '术势');
    if (tags.includes('stance_break') || effects.some(effect => ['vulnerable', 'opening'].includes(effect.kind))) role = '破势';
    else if (effects.some(effect => effect.kind === 'block')) role = '守势';
    else if (effects.some(effect => effect.kind === 'weak')) role = '控势';
    else if (effects.some(effect => ['heal', 'gain_qi'].includes(effect.kind))) role = '续势';
    if (dynamicProvenance?.role) role = dynamicProvenance.role;

    const typeName = card.type === 'attack' ? '攻击' : (card.type === 'skill' ? '技能' : '能力');
    const effectSummary = effects
      .map(effect => `${effect.target}${effect.label} ${effect.value}`)
      .join('，');
    const description = dynamicProvenance?.description || card.description || '';
    const mechanicSummary = (Array.isArray(card.effects) ? card.effects : [])
      .map(effect => {
        if (!effect.conditional_status || effect.conditional_value == null) return '';
        const normalizedStatus = statusAliases[effect.conditional_status] || effect.conditional_status;
        const statusLabel = statusNames[normalizedStatus] || normalizedStatus;
        const effectLabel = effectNames[effect.type] || '效果';
        const isTrueDamage = effect.type === 'damage'
          && (effect.true_damage === true || /真实伤害/.test(description));
        const scopedEffectLabel = `${effect.aoe === true ? '全体' : ''}${isTrueDamage ? '真伤' : effectLabel}`;
        const clauses = [];
        const conditionalAdd = typeof effect.conditional_add === 'number'
          && Number.isFinite(effect.conditional_add) ? effect.conditional_add : null;
        const conditionalMultiply = typeof effect.conditional_multiply === 'number'
          && Number.isFinite(effect.conditional_multiply) ? effect.conditional_multiply : null;
        if (conditionalAdd != null) {
          clauses.push(`${scopedEffectLabel}+${conditionalAdd}`);
        }
        if (conditionalMultiply != null) {
          clauses.push(`${scopedEffectLabel}×${conditionalMultiply}`);
        }
        if (effect.aoe === true && conditionalAdd == null && conditionalMultiply == null) {
          clauses.push(scopedEffectLabel);
        }
        if (effect.consume_status === true) {
          clauses.push(`耗尽${statusLabel}`);
        } else if (typeof effect.consume_status === 'number'
          && Number.isFinite(effect.consume_status) && effect.consume_status > 0) {
          clauses.push(`耗${effect.consume_status}${statusLabel}`);
        }
        return `${statusLabel}≥${Number(effect.conditional_value)}：${clauses.join('，') || '触发追加效果'}`;
      })
      .filter(Boolean)
      .join('；');
    const visibleDetail = mechanicSummary || (
      (!effects.length || /若|当|每|本回合|下回合|额外|触发|之后|持续|上限/.test(description))
        ? description
        : ''
    );
    const accessibleEffectText = [...new Set([effectSummary, mechanicSummary, description].filter(Boolean))].join('；');
    const exhaustText = card.exhaust ? '，此战仅用一次' : '';

    return {
      id: card.id || '',
      name: dynamicProvenance?.displayName || card.name || '无名术式',
      cost: Number(card.cost || 0),
      type: card.type || 'skill',
      typeName,
      description,
      mechanicSummary,
      visibleDetail,
      effects,
      source,
      rarity,
      cardPath,
      role,
      exhaust: !!card.exhaust,
      ariaLabel: `第${index + 1}张牌，${dynamicProvenance?.displayName || card.name || '无名术式'}，消耗${Number(card.cost || 0)}真元，${accessibleEffectText || '特殊效果'}${exhaustText}`
    };
  }

  _renderPublicCombatFacts(facts, mechanicText) {
    if (!this.mechanic) return;
    if (!facts || facts.version !== 1 || !Array.isArray(facts.rows)) {
      this.mechanic.textContent = mechanicText;
      this.decisionFacts = null;
      return;
    }
    if (!this.decisionFacts || !this.mechanic.contains(this.decisionFacts)) {
      const details = document.createElement('details');
      details.id = 'combat-decision-facts';
      const summary = document.createElement('summary');
      const description = document.createElement('span');
      description.className = 'combat-decision-mechanic';
      const affordance = document.createElement('small');
      affordance.textContent = '结算说明 · 展开 / 收起';
      summary.append(description, affordance);
      const body = document.createElement('div');
      body.id = 'combat-decision-facts-body';
      body.tabIndex = 0;
      body.setAttribute('role', 'region');
      body.setAttribute('aria-label', '当前战斗结算说明');
      details.append(summary, body);
      const scroll = document.createElement('div');
      scroll.id = 'combat-decision-scroll';
      scroll.append(details);
      this.mechanic.replaceChildren(scroll);
      this.decisionFacts = details;
    }
    this.decisionFacts.querySelector('.combat-decision-mechanic').textContent = mechanicText;
    const body = this.decisionFacts.querySelector('#combat-decision-facts-body');
    const signature = JSON.stringify(facts);
    if (body.dataset.factsSignature === signature) return;
    body.dataset.factsSignature = signature;
    const children = facts.rows.map(fact => {
      const row = document.createElement('div');
      row.dataset.combatFact = fact.id;
      const label = document.createElement('strong');
      label.textContent = fact.label;
      const text = document.createElement('span');
      text.textContent = fact.text;
      row.append(label, text);
      return row;
    });
    for (const limitation of facts.limitations || []) {
      const note = document.createElement('p');
      note.textContent = limitation;
      children.push(note);
    }
    body.replaceChildren(...children);
  }

  render(data) {
    if (!data || !data.enemy || !data.player) return;
    const context = data.context || {};
    const encounterInstanceId = String(context.encounterInstanceId
      || context.presentationId || context.cardId || data.enemy.name || 'combat');
    if (this._lastEncounterInstanceId && this._lastEncounterInstanceId !== encounterInstanceId) {
      this._clearAllSemanticActions();
      if (this.decisionFacts) this.decisionFacts.open = false;
    }
    this._lastEncounterInstanceId = encounterInstanceId;
    this._renderReaction(data.reaction, data.phase);
    const playerInputLocked = typeof deckCombatSystem !== 'undefined'
      && typeof deckCombatSystem.isPlayerInputLocked === 'function'
      && deckCombatSystem.isPlayerInputLocked();
    if (this.endTurnBtn) {
      this.endTurnBtn.disabled = Boolean(this._activeReaction) || playerInputLocked;
      this.endTurnBtn.setAttribute('aria-disabled', this.endTurnBtn.disabled ? 'true' : 'false');
    }
    this._showEncounterIntro(context, data.enemy.name);
    this._setScene(context, data.intent);
    if (this.threatBadge) this.threatBadge.textContent = context.difficultyLabel || (data.bossPhase ? '首领' : '普通');
    if (this.turnBadge) this.turnBadge.textContent = `第 ${data.turn || 1} 回合`;
    this._renderPublicCombatFacts(data.publicCombatFacts, context.mechanic || '观察敌人的行动规律，护盾会优先承受伤害');
    if (this.container) {
      const lowHealth = data.player.maxHp > 0 && data.player.hp / data.player.maxHp <= 0.34;
      this.container.classList.toggle('low-health', lowHealth);
    }
    // 渲染敌人
    this.enemyName.textContent = data.enemy.name + (data.bossPhase ? ` · ${data.bossPhase.current}/${data.bossPhase.total}相` : '');

    const renderHearts = (container, currentHp, maxHp, block) => {
      if (!container) return;
      container.innerHTML = '';

      const safeHp = Math.max(0, currentHp);
      const safeMaxHp = Math.max(1, maxHp);
      const hpPercent = Math.min(100, Math.max(0, (safeHp / safeMaxHp) * 100));
      const shieldVal = Math.max(0, block || 0);

      const wrapper = document.createElement('div');
      wrapper.className = 'combat-hp-bar-wrapper';

      const barContainer = document.createElement('div');
      barContainer.className = 'combat-hp-bar-container';

      const fill = document.createElement('div');
      fill.className = 'combat-hp-bar-fill';
      fill.style.width = `${hpPercent}%`;
      barContainer.appendChild(fill);

      if (shieldVal > 0) {
        const shieldPercent = Math.min(100, (shieldVal / safeMaxHp) * 100);
        const shieldFill = document.createElement('div');
        shieldFill.className = 'combat-shield-bar-fill';
        shieldFill.style.width = `${shieldPercent}%`;
        barContainer.appendChild(shieldFill);
      }

      wrapper.appendChild(barContainer);

      const readout = document.createElement('div');
      readout.className = 'combat-hp-readout';
      readout.innerHTML = `
        <span class="hp-num">${safeHp} / ${safeMaxHp}</span>
        ${shieldVal > 0 ? `<span class="shield-num">🛡️ ${shieldVal}</span>` : ''}
      `;
      wrapper.appendChild(readout);

      container.appendChild(wrapper);
    };

    renderHearts(this.enemyHearts, data.enemy.hp, data.enemy.maxHp, data.enemy.block);

    if (data.intent) {
        const type = data.intent.type || 'attack';
        // Raw intent.value is an authored base. Effective damage belongs to
        // DeckCombatSystem, which applies the current tier and modifiers.
        const intentPreview = data.intentPreview?.type === type ? data.intentPreview : null;
        let iconSvg = '';
        let typeName = '攻击';

        if (type === 'attack') {
            typeName = data.plan?.stateLabel || '敌方攻击';
            iconSvg = `<svg class="intent-icon-svg" viewBox="0 0 24 24"><path fill="currentColor" d="M19.7 4.3c-.4-.4-1-.4-1.4 0L12 10.6 5.7 4.3c-.4-.4-1-.4-1.4 0s-.4 1 0 1.4l6.3 6.3-6.3 6.3c-.4.4-.4 1 0 1.4.2.2.5.3.7.3s.5-.1.7-.3l6.3-6.3 6.3 6.3c.2.2.5.3.7.3s.5-.1.7-.3c.4-.4.4-1 0-1.4L13.4 12l6.3-6.3c.4-.4.4-1 0-1.4z"/></svg>`;
        } else if (type === 'defend') {
            typeName = '金刚护体';
            iconSvg = `<svg class="intent-icon-svg" viewBox="0 0 24 24"><path fill="currentColor" d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm0 10.99h7c-.53 4.12-3.28 7.79-7 8.94V12H5V6.3l7-3.11v8.8z"/></svg>`;
        } else if (type === 'debuff') {
            typeName = '幽阴施煞';
            iconSvg = `<svg class="intent-icon-svg" viewBox="0 0 24 24"><path fill="currentColor" d="M12 2a9 9 0 0 0-9 9c0 3.8 2.37 7.05 5.74 8.36L8 21a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1l-.74-1.64C18.63 18.05 21 14.8 21 11a9 9 0 0 0-9-9zm-3 8a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm6 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm-5.5 5a.5.5 0 0 1 .5-.5h4a.5.5 0 0 1 0 1h-4a.5.5 0 0 1-.5-.5z"/></svg>`;
        } else {
            typeName = '聚气玄蕴';
            iconSvg = `<svg class="intent-icon-svg" viewBox="0 0 24 24"><path fill="currentColor" d="M12 2L9.19 8.63 2 9.24l5.46 4.73L5.82 21 12 17.27 18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2z"/></svg>`;
        }

        const effectiveDamage = type === 'attack' && Number.isFinite(Number(intentPreview?.expectedDamage))
            ? Math.max(0, Number(intentPreview.expectedDamage))
            : null;
        const valueText = effectiveDamage !== null
            ? ` (${effectiveDamage})`
            : (data.intent.value ? ` (${data.intent.value})` : '');
        const descText = this._formatEffectiveActionDescription(intentPreview || data.intent, '正在观察你的破绽');
        const planStateLabel = data.plan?.stateLabel || data.intent.planStateLabel || '';
        const planCue = data.plan?.cue || data.intent.planCue || '';
        const planCause = data.plan?.recentCause ? this._planCauseLabel(data.plan.recentCause) : '';

        this.enemyIntent.className = `enemy-intent intent-badge intent-${type}`;
        this.enemyIntent.innerHTML = `
            <div class="intent-badge-icon">${iconSvg}</div>
            <div class="intent-badge-content">
                <span class="intent-type-name">${typeName}${valueText}</span>
                <span class="intent-divider">·</span>
                <span class="intent-desc-text">${descText}</span>
                ${planStateLabel && planStateLabel !== typeName ? `<span class="intent-plan-state">敌策：${planStateLabel}</span>` : ''}
                ${planCue ? `<span class="intent-plan-cue">${planCue}</span>` : ''}
                ${planCause ? `<span class="intent-plan-cause">转因：${planCause}</span>` : ''}
            </div>
        `;
    } else {
        this.enemyIntent.className = 'enemy-intent';
        this.enemyIntent.innerHTML = '';
    }

    // 渲染玩家
    renderHearts(this.playerHearts, data.player.hp, data.player.maxHp, data.player.block);

    // 渲染状态栏
    const renderStatus = (statusObj, container) => {
        container.innerHTML = '';
        if(!statusObj) return;
        for (const [key, val] of Object.entries(statusObj)) {
            if (val > 0) {
                const icon = document.createElement('div');
                icon.className = 'status-icon';
                let name = key;
                if (key === 'sword_intent') name = '剑意';
                if (key === 'spell_seal') name = '法印';
                if (key === 'vulnerable') name = '易伤';
                if (key === 'opening') name = '破绽';
                if (key === 'weak') name = '虚弱';
                if (key === 'poison') name = '丹毒';
                if (key === 'fortify') name = '金刚劲';
                if (key === 'aura') name = '罡气';
                if (key === 'qi_main_advance_ready') name = '问剑进势';
                icon.textContent = `${name}: ${val}`;
                container.appendChild(icon);
            }
        }
    };
    renderStatus(data.enemyStatus, this.enemyStatus);
    renderStatus(data.playerStatus, this.playerStatus);
    if (this.equipmentProgress) {
      const progress = Array.isArray(data.equipmentProgress) ? data.equipmentProgress : [];
      this.equipmentProgress.hidden = progress.length === 0;
      this.equipmentProgress.innerHTML = progress.map(entry => {
        const state = entry.ready ? '旧式剑路已悟 · 出手' : entry.used ? '旧式剑路已用' : `异路 ${entry.tags.length}/${entry.threshold}`;
        const tags = entry.tags.length ? ` · ${entry.tags.join(' · ')}` : '';
        return `<span class="combat-equipment-progress-entry ${entry.ready ? 'is-ready' : entry.used ? 'is-used' : ''}"><strong>${this._escapeHtml(entry.sourceItemName)}</strong><em>${this._escapeHtml(state + tags)}</em></span>`;
      }).join('');
    }

    // 真元
    this.qiVal.textContent = data.qi;
    this.maxQiVal.textContent = data.maxQi;

    // 牌堆
    this.drawCount.textContent = data.drawCount;
    this.discardCount.textContent = data.discardCount;
    this.exhaustCount.textContent = data.exhaustCount;

    // 手牌
    // Cards remain the player's controls, but their surface is a grounded
    // technique rail.  The battlefield stays visually available to the
    // character animation instead of becoming a wall of black portrait cards.
    this.handContainer.classList.add('combat-technique-rail');
    this.handContainer.dataset.combatSurface = 'technique-rail';
    this.handContainer.innerHTML = '';
    data.hand.forEach((card, index) => {
        const view = this.buildCardViewModel(card, index, context);
        const visibleDetail = this._normalizeNarrativeText(view.visibleDetail);
        const visibleDescription = this._normalizeNarrativeText(view.description);
        const cardEl = document.createElement('div');
        cardEl.className = 'battle-card combat-technique';
        cardEl.dataset.combatSurface = 'technique';
        cardEl.classList.toggle('is-exhaust', view.exhaust);
        cardEl.classList.toggle('has-detail', !!view.visibleDetail);
        cardEl.dataset.type = view.type;
        const artKey = String(card.id || '').replace(/\+$/, '');
        const art = context.cardArt?.[card.id] || context.cardArt?.[artKey] || null;
        cardEl.dataset.cardId = card.id;
        cardEl.dataset.artId = art?.id || '';
        cardEl.setAttribute('data-rarity', view.rarity);
        cardEl.setAttribute('data-source', view.source);
        cardEl.setAttribute('data-exhaust', view.exhaust ? 'true' : 'false');
        cardEl.setAttribute('data-path', view.cardPath);
        const affordable = !playerInputLocked
          && data.phase !== 'REACTION_OPEN'
          && Number(card.cost || 0) <= Number(data.qi || 0);
        // 三个不可用原因必须可区分：共用一个 unaffordable 类会让提示文案说错话
        const unavailableReason = playerInputLocked ? 'locked'
          : (data.phase === 'REACTION_OPEN' ? 'reaction' : 'qi');
        cardEl.classList.toggle('unaffordable', !affordable);
        if (affordable) delete cardEl.dataset.unavailableReason;
        else cardEl.dataset.unavailableReason = unavailableReason;
        cardEl.classList.toggle('input-locked', playerInputLocked);
        cardEl.tabIndex = affordable ? 0 : -1;
        cardEl.setAttribute('role', 'button');
        cardEl.setAttribute('aria-disabled', affordable ? 'false' : 'true');
        cardEl.setAttribute('aria-label', view.ariaLabel);

        const effectHtml = view.effects.map(effect => `
          <span class="effect-chip effect-${this._escapeHtml(effect.kind)}" data-effect-type="${this._escapeHtml(effect.kind)}">
            <small>${this._escapeHtml(effect.label)}</small>
            <strong>${this._escapeHtml(effect.value)}</strong>
          </span>
        `).join('');
        cardEl.innerHTML = `
           <div class="card-cost"><small>耗</small><strong>${view.cost}</strong></div>
           <div class="card-provenance">
             <span>${this._escapeHtml(view.rarity)}</span>
             <span>${this._escapeHtml(view.source)}</span>
           </div>
           <div class="card-name">${this._escapeHtml(view.name)}</div>
           ${art?.image ? `<div class="card-art" style="background-image:url('${art.image}')"></div>` : ''}
           <div class="card-effect-strip" aria-hidden="true">${effectHtml}</div>
           ${visibleDetail ? `<div class="card-desc" title="${this._escapeHtml(visibleDescription)}">${this._escapeHtml(visibleDetail).replace(/\n/g, '<br>')}</div>` : ''}
           ${view.exhaust ? '<div class="card-footer"><span class="card-exhaust">仅此一式</span></div>' : ''}
        `;

        // 点击出牌。不可用时必须给出可归因的拒绝反馈，而不是静默吞掉这次输入。
        cardEl.addEventListener('click', () => {
            if (affordable && typeof deckCombatSystem !== 'undefined') {
                deckCombatSystem.playCard(index);
                return;
            }
            this._showCardUnavailable(cardEl, unavailableReason);
        });
        cardEl.addEventListener('keydown', (event) => {
            if (affordable && (event.key === 'Enter' || event.key === ' ')) {
                event.preventDefault();
                if (typeof deckCombatSystem !== 'undefined') deckCombatSystem.playCard(index);
            }
        });

        this.handContainer.appendChild(cardEl);
    });

    // 日志
    this.logsContainer.innerHTML = '';
    data.log.forEach(msg => {
        const div = document.createElement('div');
        div.textContent = msg;
        this.logsContainer.appendChild(div);
    });
    this.logsContainer.scrollTop = this.logsContainer.scrollHeight;
  }

  _worldVfxColor(data = {}, world = {}) {
    const functional = world.palette?.functional || {};
    const semantic = String(data.semantic || data.type || 'impact');
    if (semantic.includes('shield') || semantic === 'treasure') return functional.player || '#8eb7ad';
    if (semantic.includes('weak') || semantic.includes('poison')) return functional.poison || '#78936c';
    if (semantic.includes('danger') || semantic.includes('break')) return functional.danger || '#a65345';
    return functional.impact || '#d7dac0';
  }

  _deferVfxForQueuedPresentation(data = {}) {
    if (data._presentationDequeuedVfx === true || !data.actionId) return false;
    const actionId = String(data.actionId);
    const queued = [...(this._semanticPresentationQueues || new Map()).values()]
      .some(queue => Array.isArray(queue) && queue.some(item => String(item?.actionId || '') === actionId));
    if (!queued) return false;
    if (!(this._pendingVfxByActionId instanceof Map)) this._pendingVfxByActionId = new Map();
    const pending = this._pendingVfxByActionId.get(actionId) || [];
    const stableEventId = String(data.vfxEventId || '');
    if (!stableEventId || !pending.some(item => String(item.vfxEventId || '') === stableEventId)) {
      pending.push({
        ...data,
        frames: Array.isArray(data.frames) ? [...data.frames] : data.frames,
        stage: data.stage && typeof data.stage === 'object' ? { ...data.stage } : data.stage
      });
    }
    this._pendingVfxByActionId.set(actionId, pending);
    if (this.container) this.container.dataset.lastFxStatus = 'queued_with_serialized_action';
    return true;
  }

  _isRuntimeEligibleWorldVfxAsset(world, asset, data = {}) {
    const contract = world?.mediaDensityContract;
    const eligibleStatuses = Array.isArray(contract?.runtimeEligibleReviewStatuses)
      ? contract.runtimeEligibleReviewStatuses : [];
    const finalStatuses = Array.isArray(contract?.finalArtEligibleReviewStatuses)
      ? contract.finalArtEligibleReviewStatuses : [];
    const registeredFrames = Array.isArray(asset?.frames) ? asset.frames : [];
    const scale = asset?.authoredTravelScale;
    const scaleRequired = asset?.requiresVisibleAlphaTravelScale === true;
    const facingCompatible = !scaleRequired
      || (asset?.placement === 'travel' && ['left', 'right'].includes(asset?.authoredFacing));
    const scaleCompatible = !scaleRequired || Boolean(
      asset?.placement === 'travel'
      && scale?.contractId === 'authored_travel_visible_alpha_scale_v2'
      && scale?.basis === 'world_unit_visible_alpha_width_from_verified_frame_bounds'
      && Number(scale.authoredVisibleWidthU) > 0
      && Number(scale.referenceAlphaWidthFraction) > 0
      && Number(scale.referenceAlphaWidthFraction) <= 1
      && Number(scale.minVisiblePx) > 0
      && Number(scale.maxVisiblePx) >= Number(scale.minVisiblePx)
      && registeredFrames.every(frame => frame?.visibleAlphaBounds
        && Number(frame.visibleAlphaBounds.width) > 0
        && Number(frame.visibleAlphaBounds.width) <= 1)
    );
    const groundScale = asset?.authoredGroundSpanScale;
    const groundScaleRequired = asset?.requiresGroundSpanScale === true;
    const groundScaleCompatible = !groundScaleRequired || Boolean(
      asset?.placement === 'contact'
      && groundScale?.contractId === 'authored_ground_conduit_footprint_v2'
      && groundScale?.basis === 'resolved_actor_ground_span_and_verified_luminous_contact_baseline'
      && Number(groundScale.referenceAlphaStartFraction) >= 0
      && Number(groundScale.referenceAlphaStartFraction) < 0.25
      && Number(groundScale.referenceAlphaSpanFraction) > 0.5
      && Number(groundScale.referenceAlphaSpanFraction) <= 1
      && Number(groundScale.referenceGroundContactYFraction) > 0.75
      && Number(groundScale.referenceGroundContactYFraction) < 0.98
      && Number(groundScale.minCarrierPx) > 0
      && Number(groundScale.maxCarrierPx) >= Number(groundScale.minCarrierPx)
      && registeredFrames.every(frame => frame?.visibleAlphaBounds
        && Number(frame.visibleAlphaBounds.width) > 0.4
        && Number(frame.visibleAlphaBounds.height) > 0
        && Number(frame.visibleAlphaBounds.height) < 0.26)
    );
    return Boolean(
      world?.id && asset?.id
      && asset.visualWorldId === world.id
      && asset.paletteSource === world?.vfxPolicy?.source
      && asset.mediaDensity === contract?.mediaDensity
      && Number(asset.logicalPixelGrid) === Number(contract?.logicalPixelGrid)
      && eligibleStatuses.includes(asset.reviewStatus)
      && (asset.finalArtApproved === false
        || (asset.finalArtApproved === true && finalStatuses.includes(asset.reviewStatus)))
      && (['travel', 'contact', 'source'].includes(asset.placement) ? asset.placement : 'contact') === data.placement
      && (!asset.authoredFacing || asset.authoredFacing === data.assetAuthoredFacing)
      && (!scaleRequired || JSON.stringify(scale) === JSON.stringify(data.assetAuthoredTravelScale))
      && (!groundScaleRequired
        || JSON.stringify(groundScale) === JSON.stringify(data.assetAuthoredGroundSpanScale))
      && typeof asset.provenanceManifest === 'string'
      && asset.provenanceManifest.endsWith('/manifest.json')
      && registeredFrames.length === 4
      && registeredFrames.every((frame, index) => frame?.frameIndex === index
        && typeof frame.path === 'string' && frame.path.endsWith('.png')
        && /^[a-f0-9]{64}$/.test(String(frame.sha256 || ''))
        && Number(frame.width) > 0 && Number(frame.height) > 0)
      && registeredFrames.length === data.frames?.length
      && registeredFrames.every((frame, index) => frame.path === data.frames[index])
      && facingCompatible
      && scaleCompatible
      && groundScaleCompatible
    );
  }

  _flushPendingVfxForAction(actionId) {
    const stableId = String(actionId || '');
    const pending = this._pendingVfxByActionId?.get(stableId) || [];
    if (!pending.length) return 0;
    this._pendingVfxByActionId.delete(stableId);
    let mounted = 0;
    for (const data of pending) {
      if (this.playVfx({ ...data, _presentationDequeuedVfx: true })) mounted += 1;
    }
    return mounted;
  }

  playVfx(data = {}) {
    const world = this._currentContext?.visualWorld || null;
    const vfxPolicy = world?.vfxPolicy || null;
    const worldRequestState = this._getVisualWorldRequestState(this._currentContext);
    const reviewedWorld = worldRequestState.resolved
      && this.container?.dataset?.visualWorldCompatible === 'true'
      && this.container?.dataset?.worldScaleResolved === 'true'
      && this.container?.dataset?.requestedMediaAllowed === 'true';
    if (worldRequestState.requested && !reviewedWorld) {
      if (this.container) this.container.dataset.lastFxStatus = 'rejected_unresolved_visual_world';
      return false;
    }
    const vfxEventId = String(data.vfxEventId || '');
    const worldMatches = Boolean(reviewedWorld
      && data.visualWorldId
      && data.visualWorldId === this._currentContext.visualWorldId
      && vfxPolicy?.rendererAuthority === 'deck_combat_ui_vfx_router_v1'
      && vfxPolicy?.source === 'functional_palette_only');
    if (reviewedWorld && (!worldMatches || !vfxEventId)) {
      if (this.container) this.container.dataset.lastFxStatus = 'rejected_world_contract';
      return false;
    }
    if (this._deferVfxForQueuedPresentation(data)) return true;

    const dedupeId = vfxEventId || `legacy:${data.actionId || 'none'}:${data.semantic || data.type || 'effect'}:${data.target || 'none'}`;
    if (this._seenVfxEventIds.has(dedupeId)) {
      if (this.container) this.container.dataset.lastFxStatus = 'deduplicated';
      return false;
    }
    this._seenVfxEventIds.add(dedupeId);

    const { type, target } = data;
    const targetEl = target === 'player' ? this.playerContainer : this.enemyContainer;
    if (!targetEl) return false;
    const authoredRequested = Boolean(data.assetId || (Array.isArray(data.frames) && data.frames.length));
    const registeredAsset = reviewedWorld ? world?.vfxAssets?.[data.assetId] : null;
    const authoredWorldCompatible = !reviewedWorld || Boolean(
      this._isRuntimeEligibleWorldVfxAsset(world, registeredAsset, data)
    );
    if (reviewedWorld && authoredRequested && !authoredWorldCompatible) {
      if (this.container) this.container.dataset.lastFxStatus = 'rejected_ineligible_authored_asset';
      this._seenVfxEventIds.delete(dedupeId);
      return false;
    }
    const authored = authoredRequested && authoredWorldCompatible;
    const carrierMode = authored ? 'authored_sprite' : 'world_fallback';
    if (this.container) {
      this.container.dataset.lastFxId = data.assetId || '';
      this.container.dataset.lastFxSemantic = data.semantic || type || '';
      this.container.dataset.lastFxEventId = dedupeId;
      this.container.dataset.lastFxSlot = data.vfxSlot || 'contact_primary';
      this.container.dataset.lastFxCarrier = carrierMode;
      if (authoredRequested && !authoredWorldCompatible) {
        this.container.dataset.lastFxStatus = 'world_fallback_incompatible_authored_asset';
      } else {
        this.container.dataset.lastFxStatus = 'mounted';
      }
    }

    if (target === 'player' && (type === 'impact' || type === 'shield_break')) {
      this._vibrate(type === 'shield_break' ? [20, 35, 20] : 35);
    }

    const stageData = { ...data, reducedMotion: this._reducedMotion };
    const makeWorldFallback = () => {
      const fallback = document.createElement('span');
      fallback.className = `combat-world-fx-fallback fx-${data.semantic || type || 'impact'}`;
      fallback.dataset.vfxEventId = dedupeId;
      fallback.dataset.vfxSlot = data.vfxSlot || 'contact_primary';
      fallback.dataset.vfxCarrier = 'world_fallback';
      fallback.dataset.peakBrightness = vfxPolicy?.contactOwnsPeakBrightness === true
        && (data.vfxSlot || 'contact_primary') === 'contact_primary' ? 'true' : 'false';
      fallback.setAttribute('aria-hidden', 'true');
      fallback.style.setProperty('--world-fx-color', this._worldVfxColor(data, world || {}));
      return fallback;
    };
    if (authored) {
      const fx = document.createElement('img');
      fx.className = `combat-sprite-fx fx-${data.semantic || type}`;
      fx.dataset.fxId = data.assetId;
      fx.dataset.vfxEventId = dedupeId;
      fx.dataset.vfxSlot = data.vfxSlot || 'contact_primary';
      fx.dataset.vfxCarrier = carrierMode;
      // Travel begins only after the complete authored sequence is decoded.
      // Otherwise a slow first-use decode can consume the whole CSS journey
      // while the sprite is still invisible, leaving only an apparent point.
      fx.dataset.vfxPlaybackState = 'preloading';
      fx.style.animationPlayState = 'paused';
      fx.dataset.peakBrightness = vfxPolicy?.contactOwnsPeakBrightness === true
        && (data.vfxSlot || 'contact_primary') === 'contact_primary' ? 'true' : 'false';
      if (data.actionId) fx.dataset.actionId = String(data.actionId);
      if (data.semantic) fx.dataset.fxSemantic = String(data.semantic);
      fx.alt = '';
      fx.draggable = false;
      const frames = this._reducedMotion ? [data.frames[Math.floor(data.frames.length / 2)]] : data.frames;
      const duration = this._reducedMotion ? 80 : Math.max(160, Number(data.durationMs) || 360);
      const frameDuration = Math.max(30, Math.floor(duration / frames.length));
      this._preloadImageSources(frames);
      const decodedFrames = frames.map(frame => this._decodePreloadedImage(frame));
      if (data.actionId) {
        const actionId = String(data.actionId);
        const pending = this._pendingVfxDecodeByActionId.get(actionId) || [];
        pending.push(decodedFrames[0]);
        this._pendingVfxDecodeByActionId.set(actionId, pending);
      }
      fx.src = frames[0];
      const replaceFailedFrame = () => {
        fx.dataset.vfxPlaybackState = 'decode_failed';
        if (!fx.isConnected) return;
        const fallback = makeWorldFallback();
        fallback.dataset.vfxRecovery = 'authored_first_frame_failed';
        fallback.classList.add('combat-stage-fx');
        for (const key of ['combatStageActionId', 'geometryPlanId', 'actorAnchorId',
          'combatStageAnchorTarget', 'actorAnchorOffsetU']) {
          if (fx.dataset[key]) fallback.dataset[key] = fx.dataset[key];
        }
        fallback.style.left = fx.style.left;
        fallback.style.top = fx.style.top;
        fx.replaceWith(fallback);
        if (this.container) this.container.dataset.lastFxStatus = 'mounted_world_fallback_after_decode_failure';
        setTimeout(() => fallback.remove(), this._reducedMotion ? 90 : 280);
      };
      const startFxFrames = () => {
        if (data.actionId && this._suppressedVfxActionIds.has(String(data.actionId))) {
          replaceFailedFrame();
          return;
        }
        const firstFrameReady = fx.complete
          ? (fx.naturalWidth > 0 ? Promise.resolve() : Promise.reject(new Error('vfx_first_frame_load_failed')))
          : new Promise((resolve, reject) => {
            fx.addEventListener('load', resolve, { once: true });
            fx.addEventListener('error', reject, { once: true });
          });
        Promise.all([firstFrameReady, decodedFrames[0]]).then(([, ready]) => {
          if (!ready) throw new Error('vfx_first_frame_decode_failed');
          if (!fx.isConnected) return;
          fx.dataset.vfxPlaybackState = 'running';
          fx.style.animationPlayState = 'running';
          let lastPresentedFrame = 0;
          frames.slice(1).forEach((frame, index) => {
            setTimeout(() => {
              const nextFrame = index + 1;
              decodedFrames[nextFrame].then(frameReady => {
                if (fx.isConnected && frameReady && nextFrame > lastPresentedFrame) {
                  fx.src = frame;
                  lastPresentedFrame = nextFrame;
                }
              });
            }, (index + 1) * frameDuration);
          });
          setTimeout(() => fx.remove(), duration + frameDuration);
        }).catch(() => {
          replaceFailedFrame();
        });
      };
      const staged = data.placement === 'travel'
        ? this.stagePresenter?.mountAcrossActors(fx, stageData, 'fx', startFxFrames)
        : (data.placement === 'source'
          ? this.stagePresenter?.mountAtActorAnchor(fx, stageData, 'fx', startFxFrames)
          : (this.stagePresenter?.mountAtContact(fx, stageData, 'fx', startFxFrames)
            || this.stagePresenter?.mountAtActorAnchor(fx, stageData, 'fx', startFxFrames)));
if (!staged) {
      if (this.container) this.container.dataset.lastFxStatus = this._stageRejectReason(stageData);
      this._countStageFx('vfxRefused');
      this._seenVfxEventIds.delete(dedupeId);
      return false;
    }
      this._countStageFx('vfxStaged');
      return true;
    }

    const fallback = makeWorldFallback();
    const removeFallback = () => setTimeout(() => fallback.remove(), this._reducedMotion ? 90 : 280);
    const staged = this.stagePresenter?.mountAtContact(fallback, stageData, 'fx', removeFallback)
      || this.stagePresenter?.mountAtActorAnchor(fallback, stageData, 'fx', removeFallback);
    if (!staged) {
      if (this.container) this.container.dataset.lastFxStatus = this._stageRejectReason(stageData);
      this._countStageFx('vfxRefused');
      this._seenVfxEventIds.delete(dedupeId);
      return false;
    }
    this._countStageFx('vfxStaged');
    return true;
  }

  // Presentation-only funnel counter. Mirrored onto the container dataset so a
  // headless run can read the result without attaching to the instance.
  _countStageFx(key) {
    const funnel = this._stageFxFunnel;
    if (!funnel || !(key in funnel)) return;
    funnel[key] += 1;
    if (this.container?.dataset) this.container.dataset.stageFxFunnel = JSON.stringify(funnel);
  }

  // Why a stage mount was refused. Geometry gating and travel-scale gating are
  // distinct failures that used to collapse into one status value, which made
  // them indistinguishable in the field. Keep them separable.
  _stageRejectReason(stageData = {}) {
    const mismatch = this.stagePresenter?.root?.dataset?.stageGeometryContractMismatch;
    if (mismatch === 'true') return 'rejected_geometry_contract_mismatch';
    if (Array.isArray(stageData?.frames) && stageData.frames.length) {
      return 'rejected_travel_no_scale_contract';
    }
    return 'rejected_geometry_no_stage';
  }
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = DeckCombatUI;
} else {
  // 初始化 UI
  document.addEventListener('DOMContentLoaded', () => {
    setTimeout(() => {
      window.deckCombatUI = new DeckCombatUI();
    }, 500); // 延迟等待 DOM
  });
}
