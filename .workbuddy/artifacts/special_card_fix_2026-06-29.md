# SPECIAL 卡牌无立绘问题 — 技术诊断与修复

## 问题

用户截图：「耳边的低语」卡牌只有文字，没有角色立绘，视觉体验空洞。

## 根因

**演示路径的 `demon_path.json`（33张）和因果交织的 `interweave.json`（16张）共 49 张卡，全部使用 `"type": "SPECIAL"` 且全部没有 `npcId` / `npcIds` 字段。**

`renderCard()` 中的立绘检测逻辑：
```js
const npcId = card.npcId || card.compId || (card.npcIds && card.npcIds[0]);
if (npcId && portraitDiv) { ... } else if (portraitDiv) {
    portraitDiv.style.display = 'none'; // ← 立绘区被隐藏
}
```

因为 SPECIAL 卡没有任何 npcId → `portraitDiv` 永远 `display:none` → 玩家看到的是一张光秃秃的文本框。

## 修复

### 设计思路

SPECIAL 卡是"天道叙事事件"——正魔抉择、因果交织、世界转折点。这些卡没有单主角，但需要视觉重量。方案：**标签驱动的主题背景 + 氛围图标 + 呼吸动画**，把立绘区从"隐藏"变成"主题气氛区"。

### 修改文件

| 文件 | 行数 | 内容 |
|------|------|------|
| `src/ui.js` | +95行 | `_renderSpecialCard()` 方法：15个标签→主题映射、图标渲染、选择注入 |
| `src/ui.js` | 修改 | `renderCard()` 新增 SPECIAL 分支（line 415）、`getCardTypeName` 新增 `SPECIAL: '天道'` |
| `styles/style.css` | +65行 | 6个主题渐变、氛围光晕、呼吸动画 |

### 主题映射

| 标签 | 主题 | 图标 | 氛围光 | 场景举例 |
|------|------|------|--------|----------|
| `demon_path` | 邪气 | ☯ | 暗红渐变 | 耳边的低语 |
| `orthodox` | 道心 | ☀ | 金色辉光 | 执事长老的警告 |
| `mystery` | 迷雾 | ◈ | 紫雾 | first_contact |
| `interweave` | 因果 | ✧ | 紫色蜿蜒 | 前世的仇 |
| `moral` | 抉择 | ⚖ | 橙金 | 清理门户 |
| `temptation` | 诱惑 | ☽ | 暗红魅惑 | 魔道的饵 |
| `sacrifice` | 牺牲 | ❖ | 暗红 | 道友托孤 |
| `betrayal` | 背叛 | ⚡ | 暗红 | 叛变 |
| default | 命运 | ※ | 深灰 | fallback |

### 修复后渲染效果

```
┌──────────────────────────────────┐
│                                  │
│          ☯ (脉动呼吸)            │  ← 主题图标 + 呼吸动画
│          邪 气                    │  ← 主题标签
│     [暗红气氛渐变背景]            │  ← 不再 display:none
│                                  │
├──────────────────────────────────┤
│  耳边响起的陌生声音...          │
│  (正常文字区)                    │
├──────────────┼───────────────────┤
│← 追问声源    │→ 无视——专心修炼  │
└──────────────┴───────────────────┘
```

### 覆盖范围

- demon_path.json: 33 张全部覆盖
- interweave.json: 16 张全部覆盖
- 未来新增 SPECIAL 卡：无匹配标签时走 default 主题，不会回到空洞状态
