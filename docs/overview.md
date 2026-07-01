# 修仙卡牌游戏 · 项目总览

## 目录架构（六层）

```
xiuxian-card-game/
├── index.html              # 入口 + 内联 DATA_MODULES
├── README.md               # 项目说明
├── src/                    # 源码层
│   ├── core/               # 核心基础设施
│   │   ├── EventBus.js     # 事件总线
│   │   ├── DataLoader.js   # 数据加载器（读 data/）
│   │   └── GameStateManager.js  # 游戏状态管理
│   ├── systems/            # 游戏系统
│   │   ├── CardSystem.js   # 卡牌抽卡（9级优先级）
│   │   ├── NpcSystem.js    # NPC 三层灵魂模型
│   │   ├── CompanionSystem.js  # 道侣系统
│   │   ├── FactionSystem.js    # 势力暗流
│   │   ├── QuestSystem.js  # 支线任务链
│   │   └── KarmaSystem.js  # 因果种子
│   ├── game.js             # 游戏主逻辑
│   └── ui.js               # UI 渲染
├── styles/                 # 样式层
│   └── style.css           # 全局样式
├── data/                   # 数据层（JSON）
│   ├── cards/              # 卡牌数据
│   ├── config/             # 配置（境界/功法）
│   ├── npcs/               # NPC 数据
│   ├── quests/             # 任务数据
│   ├── companions/         # 道侣数据
│   └── world/              # 势力/世界观
├── assets/                 # 美术资产层
│   ├── characters/         # 角色立绘 (3/8)
│   ├── backgrounds/        # 秘境背景 (0/5)
│   ├── cards/              # 卡牌插画 (0/46)
│   ├── icons/              # 图标徽章 (0/21)
│   └── vfx/                # 特效 (0/5)
├── docs/                   # 文档层
│   ├── overview.md         # 本文件
│   ├── NARRATIVE_AUDIT.md  # 叙事审计报告
│   └── ART_STYLE_SPEC.md   # 美术技术规格
└── tools/                  # 工具层
    ├── _patch_data.js      # 数据补丁脚本
    └── _patch_dialogue.js  # 对话润色脚本
```

## 重构记录

### 2026-06-27 — 目录架构重构

**执行操作**：
1. 创建六层目录：src/、styles/、assets/、data/、docs/、tools/
2. CSS 从 css/ → styles/
3. JS 从 js/ → src/（core/ + systems/ + game.js + ui.js）
4. 概念图从根目录 → assets/characters/
5. 文档从根目录 → docs/
6. 工具脚本从根目录 → tools/

**删除**：
- js/（已迁移到 src/）
- css/（已迁移到 styles/）
- 根目录重复 PNG（6张，已移入 assets/characters/）
- index.html.bak（临时备份）
- js/cards.js（死代码，572行无人引用）

**验证**：
- index.html 12处引用全部更新
- <script> 标签 13 open / 13 close 平衡
- 端到端抽卡测试通过（"剑冢共鸣"）
- 零残留旧路径引用

**数据源：** DATA_MODULES 内联于 index.html（主要），data/ JSON 为 DataLoader 备用。

## 美术资产进度

| 类别 | 完成 | 总计 | 进度 |
|------|------|------|------|
| 角色立绘 | 3 | 8 | 37.5% |
| 秘境背景 | 0 | 5 | 0% |
| 卡牌插画 | 0 | 46 | 0% |
| 图标徽章 | 0 | 21 | 0% |
| VFX 特效 | 0 | 5 | 0% |
| **合计** | **3** | **85** | **3.5%** |

**风格方向**：Lit Pixel（像素光照渲染）= 像素精灵 × 法线贴图 × 动态光照
