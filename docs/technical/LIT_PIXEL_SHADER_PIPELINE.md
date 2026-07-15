# Lit Pixel WebGL Shader 管线 — 实施报告

## 完成状态：✅ 已对接

## 架构

```
GLSL Fragment Shader (33行)
        │
        ▼
LitPixelRenderer.js (433行)
  ├─ Shader 编译 & 链接
  ├─ 纹理加载器（BaseColor + Normal + Material → GPU）
  ├─ 纹理缓存（8角色 × 3贴图 = 24张 GPU 纹理）
  ├─ 渲染缓存（dataURL，光圈参数变化时自动失效）
  ├─ 光照动画（NPC 面板打开时自动旋转光源）
  └─ 回退机制（WebGL 不可用时 → Canvas2D 静态贴图）
        │
        ▼
index.html
  ├─ <canvas id="npc-avatar-canvas">    NPC 头像
  ├─ <canvas id="comp-avatar-canvas">   道侣头像
  └─ 启动脚本：init + 预加载8角色

src/ui.js
  ├─ openNpcPanel() → LitPixel.renderToCanvas + startLightAnimation
  ├─ openCompanionPanel() → 同上
  ├─ openNpcList() → LitPixel.renderToDataURL 批量缩略图
  └─ 关闭/告辞 → stopLightAnimation
```

## Shader 光照模型

| 光照分量 | 公式 | 参数 |
|----------|------|------|
| **漫反射** | `NdotL × lightIntensity` | `lightIntensity=0.72` |
| **环境光** | `ambientColor × ambientStrength` | `ambientStrength=0.28` |
| **边缘光** | `(1-abs(N·V))^rimPower × rimIntensity` | `rimPower=2.5, rimIntensity=0.35` |
| **高光** | `Blinn-Phong`, shininess ∝ roughness | `specIntensity=0.12` |
| **自发光** | `baseColor × material.b × 0.5` | 来自 material 贴图 B 通道 |

## 文件变更

| 文件 | 操作 | 说明 |
|------|------|------|
| `src/systems/LitPixelRenderer.js` | **新建** | 433行 WebGL 渲染器 |
| `index.html` | 修改 | `<img>` → `<canvas>` ×2，启动脚本加 init+预加载 |
| `src/ui.js` | 修改 | NPC/道侣/列表三处接入 LitPixelRenderer |
| `styles/style.css` | 修改 | 头像 56→80px，加 pixelated 渲染 + 发光边框 |

## 光照动画

- NPC 面板打开时，光源绕角色缓慢旋转（每帧 0.008 rad）
- 关闭面板/告辞时自动停止动画（cancelAnimationFrame）
- 渲染缓存 key 绑定光圈参数 → 动画不命中缓存（每次都是新渲染）

## 性能预算

| 项目 | 数量 | 内存 |
|------|------|------|
| GPU 纹理（8角色 ×3） | 24张 | ~9.4 MB |
| 渲染缓存（PNG dataURL） | 可变 | ~50KB/条 |
| WebGL draw call | 1 次/角色/帧（动画） | < 1ms |
| 动画帧率 | requestAnimationFrame | 60fps |

## 已知限制

1. **WebGL 1.0** — 未用 WebGL2（兼容性优先），NPOT 纹理不支持 mipmap（已设 NEAREST）
2. **法线空间** — 假设为切线空间法线（蓝底），未做切线变换
3. **视线方向** — 固定为 +Z（正对屏幕），适用于 2D 卡片角色
4. **纯 Canvas 环境** — 不依赖 Three.js/引擎，零外部依赖

## 光照参数预设

```js
{
  dir:             [0.5, -0.8, 0.3],   // 右上光源
  rimColor:        [0.4, 0.6, 0.9],    // 青蓝边缘光
  ambientColor:    [0.25, 0.22, 0.35], // 暗紫环境光
  rimPower:        2.5,
  rimIntensity:    0.35,
  ambientStrength: 0.28,
  specIntensity:   0.12,
  lightIntensity:  0.72,
}
```

可运行时修改：`window.litPixelRenderer.setLight({ rimIntensity: 0.6 })`
