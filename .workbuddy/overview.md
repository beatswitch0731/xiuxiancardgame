# 叙事系统补全 — 概述

## 做了什么

为修仙卡牌游戏补全了叙事真空，创建并接入了两套新卡牌组 + 补全了之前缺失的4个卡牌模块到 DATA_MODULES。

## 新卡牌组

### story_dialogue.json (22张)
高质量 NPC 对话驱动的情节卡，覆盖炼气→化神五个境界。每张卡包含：
- 完整的角色对白与叙事文学描写
- 两个有意义的道德/情感选择
- `tags` 挂接 StoryNetworkSystem 弧线推进
- `once: true` — 每张只在游戏中出现一次

**化神终局新增**：`sd_dt_all_companions_gather`（全员告别）、`sd_dt_final_choice`（飞升或留下）

### world_atmosphere.json (15张)
让世界"呼吸"的轻量氛围卡：
- 茶馆流言、路人闲话、市井传说
- 低权重、可重复出现
- 无重大选择，仅营造沉浸感

## 技术变更

1. **CardSystem.js**：`init()` 新增两行 `_loadExtraModule` 调用
2. **index.html**：注入 6 个模块到 `DATA_MODULES`（其中4个是既有缺失模块的补全）
3. 每境界叙事密度均衡：7-7-9-7-7

## 数据流验证

`_loadExtraModule` → `cardCache` → `_drawNormal()` 按 `realm` 自动匹配境界池 ← 已验证
