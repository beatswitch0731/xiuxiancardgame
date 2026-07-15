class DeckCombatUI {
  constructor() {
    this.container = document.getElementById('deck-combat-screen');
    
    // 缓存 DOM 节点
    this.enemyName = document.getElementById('combat-enemy-name');
    this.enemyIntent = document.getElementById('combat-enemy-intent');
    this.enemyHearts = document.getElementById('combat-enemy-hearts');
    this.enemyStatus = document.getElementById('combat-enemy-status');
    
    this.playerHearts = document.getElementById('combat-player-hearts');
    this.playerStatus = document.getElementById('combat-player-status');
    
    this.qiVal = document.getElementById('combat-qi-val');
    this.maxQiVal = document.getElementById('combat-max-qi-val');
    
    this.drawCount = document.getElementById('combat-draw-count');
    this.discardCount = document.getElementById('combat-discard-count');
    this.exhaustCount = document.getElementById('combat-exhaust-count');
    
    this.handContainer = document.getElementById('combat-player-hand');
    this.logsContainer = document.getElementById('deck-combat-logs');
    
    this.endTurnBtn = document.getElementById('combat-end-turn-btn');
    
    this.init();
  }
  
  init() {
    if (!this.container) return;
    
    // 监听逻辑层更新
    eventBus.on('combat:updated', (data) => this.render(data));
    eventBus.on('combat:anim', (data) => this.playAnim(data));
    
    // 绑定按钮事件
    this.endTurnBtn.addEventListener('click', () => {
       if (typeof deckCombatSystem !== 'undefined') {
           deckCombatSystem.endTurn();
       }
    });
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
      } else if (data.type === 'floating_text') {
          const floater = document.createElement('div');
          floater.className = 'floating-text';
          floater.textContent = data.text;
          floater.style.color = data.color || '#fff';
          
          // Randomize slightly so they don't overlap completely
          const offsetX = (Math.random() - 0.5) * 40;
          const offsetY = (Math.random() - 0.5) * 20;
          floater.style.left = `calc(50% + ${offsetX}px)`;
          floater.style.top = `calc(50% + ${offsetY}px)`;
          floater.style.transform = 'translate(-50%, -50%)';
          
          targetEl.style.position = 'relative'; // Ensure relative parent
          targetEl.appendChild(floater);
          
          setTimeout(() => {
              if (floater.parentNode) floater.parentNode.removeChild(floater);
          }, 1000);
      }
  }
  
  render(data) {
    // 渲染敌人
    this.enemyName.textContent = data.enemy.name;
    
    const renderHearts = (container, currentHp, maxHp, block) => {
        if (!container) return;
        container.innerHTML = '';
        for (let i = 0; i < maxHp; i++) {
            const heart = document.createElement('div');
            heart.className = 'heart';
            if (i >= currentHp) {
                heart.classList.add('empty');
            }
            if (block > 0) {
                heart.classList.add('shielded');
            }
            container.appendChild(heart);
        }
        if (block > 0) {
            const shieldText = document.createElement('span');
            shieldText.style.color = '#4caf50';
            shieldText.style.fontWeight = 'bold';
            shieldText.style.marginLeft = '8px';
            shieldText.textContent = `🛡️ ${block}`;
            container.appendChild(shieldText);
        }
    };
    
    renderHearts(this.enemyHearts, data.enemy.hp, data.enemy.maxHp, data.enemy.block);
    
    if (data.intent) {
        let icon = '⚔️';
        if (data.intent.type === 'defend') icon = '🛡️';
        if (data.intent.type === 'debuff') icon = '💀';
        if (data.intent.type === 'buff') icon = '✨';
        this.enemyIntent.innerHTML = `${icon} ${data.intent.desc}`;
    } else {
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
                if (key === 'vulnerable') name = '易伤';
                if (key === 'weak') name = '虚弱';
                icon.textContent = `${name}: ${val}`;
                container.appendChild(icon);
            }
        }
    };
    renderStatus(data.enemyStatus, this.enemyStatus);
    renderStatus(data.playerStatus, this.playerStatus);
    
    // 真元
    this.qiVal.textContent = data.qi;
    this.maxQiVal.textContent = data.maxQi;
    
    // 牌堆
    this.drawCount.textContent = data.drawCount;
    this.discardCount.textContent = data.discardCount;
    this.exhaustCount.textContent = data.exhaustCount;
    
    // 手牌
    this.handContainer.innerHTML = '';
    data.hand.forEach((card, index) => {
        const cardEl = document.createElement('div');
        cardEl.className = 'battle-card';
        cardEl.dataset.type = card.type;
        
        cardEl.innerHTML = `
           <div class="card-cost">${card.cost}</div>
           <div class="card-name">${card.name}</div>
           <div class="card-type">${card.type === 'attack' ? '攻击' : (card.type === 'skill' ? '技能' : '能力')}</div>
           <div class="card-desc">${card.description}</div>
        `;
        
        // 点击出牌
        cardEl.addEventListener('click', () => {
            if (typeof deckCombatSystem !== 'undefined') {
                deckCombatSystem.playCard(index);
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
  }
}

// 初始化 UI
document.addEventListener('DOMContentLoaded', () => {
   setTimeout(() => {
       window.deckCombatUI = new DeckCombatUI();
   }, 500); // 延迟等待 DOM
});
