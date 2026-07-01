# 一念仙途 · 道侣立绘阶段系统 + 万物志面板 + 魔道女修事件

**完成时间**: 2026-06-27 21:03 | **测试**: 135/135 全绿

---

## 新增文件

| 文件 | 内容 |
|------|------|
| `data/companions/portrait_stages.json` | 5位道侣 × 23个立绘阶段的完整数据模型 |
| `data/cards/demonic_seductress.json` | 10张魔道女修以色换资源事件卡 |

## 修改文件

| 文件 | 改动 |
|------|------|
| `index.html` | +万物志面板DOM +卡牌立绘切换按钮 +万物志按钮 |
| `styles/style.css` | +~180行万物志/立绘切换样式 |
| `src/ui.js` | +~250行万物志面板/立绘切换/阶段渲染逻辑 |
| `src/systems/CardSystem.js` | +`_loadExtraModule()` +`_drawNormal()`额外卡池合并 |
| `tools/_rebuild_data.js` | +2模块映射(portrait_stages + demonic_seductress) |

## 核心架构

### 立绘阶段系统
```
好感度 0  → 白狐被困 (幼狐形态)
好感度 20 → 初见报恩 (白衣银发)
好感度 40 → 参汤相伴 (托腮凝望)
好感度 60 → 月下修行 (薄纱环绕)
好感度 80 → 天命道侣 (婚契符文)
好感度 90 → 半掩狐媚 (纱衣半解) 🔞
```

### 万物志面板三标签
- ♥ **道侣** — 所有道侣的立绘阶段画廊 + 阶段解锁圆点 + 内嵌立绘查看器
- 🔮 **万物** — 灵石/寿元/法宝/丹药的资源展示
- 📜 **功法** — 当前功法的所有技能（解锁/锁定状态）

### 魔道女修事件
- 10张卡分散在 foundation→deity 四境界
- NPC_ENCOUNTER(遇血玫/月湖妖女/灵脉之女/柳如烟/虎娘) + COMPANION_EVENT(魔女报恩/正魔双修/魔纹之夜) + NORMAL(魔道拍卖/丹房)
- 全部带 `narrativeBlock` 展开叙事 + `_adultThemes` 标记

## 待后续

- 立绘阶段贴图需用多模态内容生成工具逐一生成并放入 `assets/characters/`
- 魔道女修卡的 `requiresFlag` (如 `companion_ds_demoness_acquired`) 需要对应 flag 在游戏流程中被正确设置
- 移动端万物志面板响应式优化
