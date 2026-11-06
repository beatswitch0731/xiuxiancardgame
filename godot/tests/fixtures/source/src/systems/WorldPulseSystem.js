/**
 * WorldPulseSystem - 把玩家行为、势力暗流、地区与真相进度汇总为活世界脉搏。
 * 所有指标均为叙事调度信号，不直接修改玩家战斗数值。
 */
class WorldPulseSystem {
  constructor() {
    this.state = null;
    this._lastBroadcastTurn = -1;
    this._initialized = false;
  }

  init() {
    if (this._initialized) return false;
    const restored = typeof gameState !== 'undefined' ? gameState.worldPulseState : null;
    this.reset();
    if (restored) this.hydrateState(restored);
    if (typeof eventBus === 'undefined') return false;
    this._initialized = true;
    eventBus.on('state:reset', () => this.reset());
    eventBus.on('card:chosen', payload => this._onChoice(payload));
    eventBus.on('state:clueGained', () => this._adjust({ truth: 12, instability: 1 }, 'truth'));
    eventBus.on('faction:undercurrentChanged', data => {
      this._adjust({ instability: Math.max(1, Number(data.stage) || 1) }, 'faction');
    });
    eventBus.on('combat:victorySettled', () => this._adjust({ hope: 2, instability: -1 }, 'victory'));
    eventBus.on('combat:defeatSettled', () => this._adjust({ hope: -2, instability: 2 }, 'defeat'));
    eventBus.on('state:locationChanged', () => this.broadcast(true));
    return true;
  }

  reset() {
    const inheritedTruth = typeof gameState !== 'undefined' && Array.isArray(gameState.clues)
      ? Math.min(100, gameState.clues.length * 12)
      : 0;
    this.state = {
      instability: 18,
      scarcity: 22,
      hope: 50,
      truth: inheritedTruth,
      dominantTag: 'serene',
      lastCause: '轮回初醒'
    };
    this._lastBroadcastTurn = -1;
    if (typeof gameState !== 'undefined') gameState.worldPulse = this.state;
  }

  _onChoice({ card, choice } = {}) {
    if (!choice) return;
    const effects = choice.effects || {};
    const delta = {};
    if (Number(effects.karmaGood) > 0) delta.hope = 2;
    if (Number(effects.karmaBad) > 0) {
      delta.instability = 2;
      delta.hope = (delta.hope || 0) - 1;
    }
    if (Number(effects.spiritStone) < 0) delta.scarcity = -1;
    if (choice.triggerCombat || effects.triggerCombat || card?.type === 'COMBAT') delta.instability = (delta.instability || 0) + 1;
    if (card?.type === 'LOCATION' || card?.type === 'STORY') delta.hope = (delta.hope || 0) + 1;
    this._adjust(delta, card?.title || choice.text || '无名选择');
    this.broadcast(false);
  }

  _adjust(delta, cause) {
    for (const key of ['instability', 'scarcity', 'hope', 'truth']) {
      if (!Number.isFinite(Number(delta[key]))) continue;
      this.state[key] = Math.max(0, Math.min(100, this.state[key] + Number(delta[key])));
    }
    this.state.lastCause = cause || this.state.lastCause;
    this.state.dominantTag = this._deriveMood();
    if (typeof gameState !== 'undefined') gameState.worldPulse = this.state;
  }

  _deriveMood() {
    if (this.state.truth >= 60) return 'revelation';
    if (this.state.instability >= 65) return 'crisis';
    if (this.state.hope >= 70) return 'flourishing';
    if (this.state.scarcity >= 65) return 'scarcity';
    const location = typeof gameState !== 'undefined' ? gameState.currentLocation : '';
    if (location === '秘境' || location === '天道虚空') return 'mystery';
    if (location === '魔域') return 'ominous';
    if (location === '坊市') return 'bustling';
    return 'serene';
  }

  getSnapshot() {
    const mood = this._deriveMood();
    const headlines = {
      serene: '灵脉平稳，诸宗暂息兵戈。',
      bustling: '商路繁忙，坊市流言比灵石更快。',
      mystery: '旧日禁制松动，失落的真相正在浮现。',
      ominous: '魔气越过边界，正邪盟约摇摇欲坠。',
      crisis: '天下暗流汇聚，下一次选择可能改变格局。',
      flourishing: '你留下的善意正在陌生之处开花。',
      scarcity: '灵脉与商路同时收紧，各方开始争夺资源。',
      revelation: '证据开始相互印证，天道的裂缝已无法遮掩。'
    };
    return { ...this.state, dominantTag: mood, headline: headlines[mood] };
  }

  exportState() {
    return {
      version: 1,
      state: { ...this.state },
      lastBroadcastTurn: this._lastBroadcastTurn
    };
  }

  hydrateState(snapshot) {
    if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)
      || !snapshot.state || typeof snapshot.state !== 'object' || Array.isArray(snapshot.state)) {
      return false;
    }
    const defaults = this.state || {};
    const restored = {};
    for (const key of ['instability', 'scarcity', 'hope', 'truth']) {
      restored[key] = Number.isFinite(Number(snapshot.state[key]))
        ? Math.max(0, Math.min(100, Number(snapshot.state[key])))
        : defaults[key];
    }
    this.state = {
      ...restored,
      dominantTag: typeof snapshot.state.dominantTag === 'string'
        ? snapshot.state.dominantTag : defaults.dominantTag,
      lastCause: typeof snapshot.state.lastCause === 'string'
        ? snapshot.state.lastCause : defaults.lastCause
    };
    this._lastBroadcastTurn = Number.isFinite(Number(snapshot.lastBroadcastTurn))
      ? Math.floor(Number(snapshot.lastBroadcastTurn)) : -1;
    if (typeof gameState !== 'undefined') gameState.worldPulse = this.state;
    return true;
  }

  broadcast(force = false) {
    const turn = typeof gameState !== 'undefined' ? gameState.turn : 0;
    if (!force && turn === this._lastBroadcastTurn) return;
    this._lastBroadcastTurn = turn;
    eventBus.emit('world:pulse', this.getSnapshot());
  }
}

const worldPulseSystem = new WorldPulseSystem();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = WorldPulseSystem;
} else if (typeof window !== 'undefined') {
  window.WorldPulseSystem = WorldPulseSystem;
  window.worldPulseSystem = worldPulseSystem;
}
