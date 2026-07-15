# P0 修复报告 — 技术美术资产整改

**日期**: 2026-06-27  
**审计来源**: docs/ASSET_AUDIT_REPORT.md (三项 P0 问题)

---

## P0-1: 角色立绘降分辨率 + WebP压缩 ✅

| 指标 | 修复前 | 修复后 | 改善 |
|------|--------|--------|------|
| 尺寸 | 768×944 | 512×768 | **规格合规** |
| 格式 | PNG RGB | WebP 85% | — |
| 单文件 | ~820KB | 26~50KB | **-95%** |
| 8角色合计 | 6,594KB (6.4MB) | 306KB (0.3MB) | **-95.4%** |

**方法**: 等比中心裁剪 → NEAREST缩放 → WebP Q85  
**脚本**: `tools/_resize_characters.py`  
**代码更新**: `index.html` + `src/ui.js` 全部 .png → .webp (0残留引用)

---

## P0-2: 图标Alpha通道 ✅

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| 模式 | RGB (无透明) | RGBA (有透明) |
| 角点Alpha | 255 (不透明) | 0 (全透明) |
| 透明占比 | 0% | 54%-93% |

**方法**: 角点泛洪算法 → 亮度+饱和度联合判断背景  
**脚本**: `tools/_add_icon_alpha.py`  
**全部6个图标**: `icon_sword`, `icon_spell`, `icon_body`, `icon_pill`, `icon_spirit_stone`, `icon_lifespan`

---

## P0-3: 法线贴图 + 材质贴图 ✅

| 贴图类型 | 通道 | 说明 |
|----------|------|------|
| Normal Map | RGB | Sobel梯度 → 切线空间法线 |
| Material Map | R=粗糙度, G=金属度, B=AO, A=自发光 | 像素艺术材质参数 |

**生成**: 8角色 × 2贴图 = 16张  
**体积**: 2,737KB 总计  
**脚本**: `tools/_generate_pbr_maps.py`

> ⚠️ 法线/材质贴图在纯CSS渲染中暂不生效，它们是Lit Pixel Shader的预备资产。需要在Canvas/WebGL渲染管线中集成才能启用光照。

---

## 最终资产总览

| 目录 | 文件数 | 总体积 | Alpha状态 |
|------|--------|--------|-----------|
| `characters/` | 24 | 3,042KB | WebP×8 + Normal×8 + Material×8 |
| `icons/` | 6 | 133KB | **全部RGBA透明** ✅ |
| `cards/` | 2 | 554KB | RGB (封面/背面无需透明) |
| `backgrounds/` | 2 | 1,794KB | RGB |
| **总计** | **34** | **5,524KB (5.4MB)** | — |

### 对比修复前

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| 角色体积 | 6,594KB | 306KB |
| 总资产体积 | ~8,900KB | 5,524KB |
| 图标Alpha | 全部RGB | 全部RGBA |
| PBR贴图 | 无 | 16张 (Normal+Material) |

---

## 残留建议

1. **背景图WebP化**: `bg_start.png`(839KB) + `bg_game.png`(956KB) → 可压缩至~150KB/张
2. **卡牌WebP化**: `card_face.png`(295KB) + `card_back.png`(259KB) → 可压缩至~50KB/张
3. **bg_game.png 可见性**: CSS opacity 0.08 几乎不可见，建议改背景色替代或用更轻的纹理
4. **Shader集成**: Normal/Material贴图已就位，待Canvas WebGL Shader管线实现
