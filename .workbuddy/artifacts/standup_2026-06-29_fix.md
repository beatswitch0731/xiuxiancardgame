# 立绘对齐 + 日志面板修复报告

**日期**: 2026-06-29 06:10

## 完成的五项修复

### 1. 立绘阶段对齐（16个死链 → 全部修复）
`portrait_stages.json` 中引用的 16 个 `.webp` 阶段文件不存在，已全部映射到实际存在的文件：

| 角色 | 死链数 | 修复方案 |
|------|--------|---------|
| 白落霜 | 5 | 前4个→基础 concept.webp；seductive→v8_greeksculpt.png |
| 剑灵儿 | 3 | 全部→concept_jian_linger.webp |
| 慕青岚 | 3 | 全部→concept_mu_qinglan.webp |
| 九尾溯月 | 2 | tales/intimate→concept_jiuwei_suyue.webp |
| 殷血 | 3 | swordmate/protector→concept_yin_xue.webp；intimate→intimate_v3_pixel.png |

### 2. 天机老人 + 血煞老祖 立绘阶段
新增 `portrait_stages.json` 条目，各配 1 个基础阶段（使用已有 concept_x.webp）。

### 3. 图像 onerror 全面回退
`ui.js` 中 4 个图像加载点全部添加 onerror：
- `_fallbackAvatar` → Canvas 像素风占位符
- `_fallbackCardPortrait` → 暗色占位 div (⚔)
- `_fallbackPortraitStage` → "立绘未就绪" Canvas
- `_renderPortraitStage` 直接加载 → 级联 fallbackPortraitStage

### 4. 日志面板彻底浮层化
**核心改动**: `position: absolute; pointer-events: none` (折叠态)

- 不再占用布局空间，不再推开选项按钮
- 折叠高度 28px，仅显示"仙途日志"标题
- 点击穿透到后方按钮区域
- hover 展开至 160px 查看完整日志

### 5. 删除 nul 文件
Windows 保留名文件 `assets/characters/nul` (47 bytes) 已删除。

## 验证结果
- ✅ 所有 JS 文件语法通过
- ✅ portrait_stages.json 合法 JSON
- ✅ 卡牌美术资源完整（tianji/xuesha card png 均存在）
