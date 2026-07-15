# 管理员操作日志 (Admin Log)

> 此日志用于记录全局架构变动、新技术的引入，以及底层关键文件的分布与变动情况，以便于您（主架构师）随时查阅。

## 2026-07-01：引入 Git 版本控制与 Three.js 混合渲染筹备

### 1. 版本控制系统介入
- **操作**：在 `E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game` 目录执行了 `git init`。
- **分支**：已创建并切换到实验性分支 `feature/threejs-integration`。
- **目的**：隔离 3D 渲染层的开发风险，如果效果不符合预期或导致严重的性能退化，可以随时丢弃该分支，保护主线代码安全。

### 2. Three.js 2.5D 混合渲染架构规划
即将引入 Three.js 用于渲染底层的“环境灵气粒子”系统，增强修仙沉浸感。以下是预期的文件布局：

| 操作类型 | 文件路径 | 作用描述 |
| :--- | :--- | :--- |
| **[新增]** | `src/systems/ThreeBackgroundSystem.js` | 核心 3D 渲染系统，负责创建 WebGL 场景、相机与粒子系统，并监听 `flow:phaseChanged`。 |
| **[修改]** | `index.html` | 在底部（`z-index: -1`）插入 `<div id="three-canvas-container">`；引入 Three.js 的 CDN `<script>`；并加载并初始化 `ThreeBackgroundSystem`。 |
| **[修改]** | `styles/style.css` | 为 3D 容器添加 CSS 定位，确保它处于背景层且不阻挡上层的 DOM 鼠标/触摸事件（`pointer-events: none`）。 |

*(持续记录中...)*
