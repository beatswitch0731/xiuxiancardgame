# Cocos Creator 修仙卡牌决策游戏开发流程

> 基于《修仙卡牌决策游戏GDD_v0.5.md》的落地方案
> 目标：零Cocos经验也能跟着走，把GDD变成可玩的TapTap手游

---

## 一、为什么选Cocos Creator 3.8

| 维度 | 推荐原因 | 说明 |
|------|----------|------|
| **TapTap生态** | 国内独立手游首选 | 大量国产卡牌/独立游戏用Cocos，上架文档成熟 |
| **包体** | 空包~12MB | 比Unity轻，比Godot更被TapTap渠道熟悉 |
| **TypeScript** | 前端开发者友好 | 有JS/TS基础就能写，不用学C#或GDScript |
| **2D UI** | 适合卡牌游戏 | UI系统、动画系统、粒子系统都很成熟 |
| **分包/热更** | 国内刚需 | 后续更新内容不用重新发包 |

**结论**：如果你只会前端/JS基础，Cocos Creator是最短路径。

---

## 二、安装与环境（30分钟）

### 1. 下载安装

1. 访问 https://www.cocos.com/creator
2. 下载 **Cocos Creator 3.8.x LTS**（推荐3.8.4，稳定）
3. 安装时会同时安装 **Cocos Dashboard**（项目管理器）
4. 注册Cocos账号（免费）

### 2. 第一次创建项目

1. 打开 Cocos Dashboard → 点击 **新建项目**
2. 选择模板：**Empty (2D)**
3. 项目名称：`YiNianXianTu`（或你喜欢的中文名）
4. 选择路径：不要中文路径！不要空格！
5. 点击创建，等待项目初始化（约2-3分钟）

### 3. 编辑器初识（5个关键区域）

| 区域 | 作用 | 你主要用它干嘛 |
|------|------|---------------|
| **层级管理器** | 场景里的所有节点 | 摆放UI、卡牌、按钮 |
| **资源管理器** | 所有图片/脚本/预制体 | 拖资源、创建脚本 |
| **场景编辑器** | 可视化编辑2D/3D场景 | 摆UI位置 |
| **属性检查器** | 选中节点的属性面板 | 调组件参数、关联图片 |
| **控制台** | 报错和日志 | 调试 |

---

## 三、项目结构规划

在 `assets/` 目录下按以下结构建文件夹：

```
assets/
├── scripts/              # 代码
│   ├── core/             # 核心逻辑：状态、存档、卡牌池
│   ├── data/             # 数据表、JSON配置
│   ├── ui/               # UI组件脚本
│   ├── game/             # 游戏流程控制
│   └── utils/            # 工具函数
├── resources/            # 动态加载资源
│   ├── cards/            # 卡牌背景图
│   ├── characters/       # 角色立绘
│   ├── artifacts/        # 法宝图标
│   ├── ui/               # UI图片、按钮、属性条
│   └── audio/            # 音效、BGM
├── prefabs/              # 预制体
│   ├── Card.prefab       # 卡牌模板
│   ├── AttributeBar.prefab # 属性条
│   ├── PillSlot.prefab   # 丹药槽
│   └── ArtifactSlot.prefab # 法宝槽
├── scenes/               # 场景
│   ├── Boot.scene        # 启动场景（加载资源）
│   ├── MainMenu.scene    # 主菜单
│   ├── Game.scene        # 主游戏场景
│   └── Ending.scene      # 结局场景
├── fonts/                # 字体
└── gameData/             # 卡牌JSON、配置JSON
    ├── cards/            # 各境界卡牌JSON
    ├── config.json       # 全局配置
    └── story/            # 结局文本等
```

> 注意：Cocos 中 `resources` 文件夹是特殊目录，里面的资源可以通过代码动态加载。

---

## 四、核心架构：一个卡牌游戏需要哪些模块

### 模块关系图

```
GameManager (单例，游戏总控)
    ├── GameState (玩家当前状态：五维属性、资源、境界、功法)
    ├── CardPool (卡池系统：根据条件抽卡、权重计算)
    ├── CardDataManager (加载所有JSON卡牌数据)
    ├── KarmaSystem (因果系统：种子、发芽、宿命卡)
    ├── TribulationManager (渡劫Boss战)
    ├── DungeonManager (秘境节点地图)
    ├── SaveManager (存档/读档)
    ├── UIManager (界面控制)
    └── EffectManager (音效、粒子、震动)
```

### 每个模块一句话职责

| 模块 | 职责 | 为什么重要 |
|------|------|-----------|
| **GameManager** | 单例总控，协调所有模块 | 避免代码乱成一团 |
| **GameState** | 存当前玩家数据 | 所有属性、资源、标签、境界 |
| **CardDataManager** | 读取JSON卡牌配置 | 把GDD的内容变成代码能用的数据 |
| **CardPool** | 按条件筛选、加权抽卡 | 核心玩法，天机盘也改这里 |
| **KarmaSystem** | 管理因果种子 | 发芽、宿命卡、渡劫结算 |
| **TribulationManager** | 渡劫流程和限时 | 突破核心体验 |
| **DungeonManager** | 秘境节点和战斗 | 节奏变化 |
| **SaveManager** | 自动存档/转世存档 | 中断续玩 |
| **UIManager** | 卡牌界面、属性条、弹窗 | 玩家看到的一切 |
| **EffectManager** | 音效、震动、粒子反馈 | 手感来源 |

---

## 五、脚本模块代码骨架

### 1. GameState.ts（玩家状态）

```typescript
import { _decorator, Component, sys } from 'cc';
const { ccclass, property } = _decorator;

export interface PlayerState {
  // 五维属性
  cultivation: number;   // 修为
  daoHeart: number;      // 道心
  karmaGood: number;     // 善因
  karmaBad: number;      // 恶因
  fortune: number;       // 福缘
  health: number;        // 气血
  
  // 资源
  spiritStone: number;   // 灵石
  lifespan: number;      // 寿元
  pills: string[];       // 丹药ID列表
  artifacts: string[];   // 法宝ID列表
  companions: string[];  // 道侣ID列表
  
  // 境界/进度
  realm: string;         // 当前境界
  tags: string[];        // 玩家标签
  build: string;         // 当前功法
  yuanshenEnergy: number; // 元神能量
}

@ccclass('GameState')
export class GameState extends Component {
  private state: PlayerState;
  
  start() {
    this.resetState();
  }
  
  resetState() {
    this.state = {
      cultivation: 20, daoHeart: 50,
      karmaGood: 0, karmaBad: 0,
      fortune: 30, health: 30,
      spiritStone: 0, lifespan: 80,
      pills: [], artifacts: [], companions: [],
      realm: 'QI_CONDENSATION', tags: [],
      build: '', yuanshenEnergy: 1
    };
  }
  
  getState() { return this.state; }
  
  applyStatChanges(changes: any) {
    this.state.cultivation = Math.max(0, Math.min(100, this.state.cultivation + (changes.cultivation || 0)));
    this.state.daoHeart = Math.max(0, Math.min(100, this.state.daoHeart + (changes.dao || 0)));
    this.state.karmaGood = Math.max(0, Math.min(50, this.state.karmaGood + (changes.karmaGood || 0)));
    this.state.karmaBad = Math.max(0, Math.min(50, this.state.karmaBad + (changes.karmaBad || 0)));
    this.state.fortune = Math.max(0, Math.min(100, this.state.fortune + (changes.fortune || 0)));
    this.state.health = Math.max(0, Math.min(100, this.state.health + (changes.health || 0)));
    this.checkDeath();
  }
  
  checkDeath() {
    if (this.state.cultivation <= 0) return 'FALL_CULTIVATION';
    if (this.state.daoHeart <= 0) return 'FALL_DAO';
    if (this.state.health <= 0) return 'FALL_HEALTH';
    if (this.state.lifespan <= 0) return 'FALL_LIFESPAN';
    return null;
  }
}
```

### 2. CardDataManager.ts（加载卡牌数据）

```typescript
import { _decorator, Component, resources, JsonAsset } from 'cc';
const { ccclass } = _decorator;

@ccclass('CardDataManager')
export class CardDataManager extends Component {
  private allCards: any[] = [];
  
  async loadAllCards() {
    const files = [
      'gameData/cards/qi_condensation',
      'gameData/cards/foundation_building',
      'gameData/cards/golden_core',
      // ... 更多
    ];
    
    for (let f of files) {
      const asset = await new Promise<any>((resolve) => {
        resources.load(f, JsonAsset, (err, asset) => resolve(err ? null : asset));
      });
      if (asset) this.allCards = this.allCards.concat(asset.json.cards);
    }
  }
  
  getCards() { return this.allCards; }
}
```

### 3. CardPool.ts（卡池/抽卡）

```typescript
import { _decorator, Component } from 'cc';
const { ccclass } = _decorator;

@ccclass('CardPool')
export class CardPool extends Component {
  private bag: any[] = [];
  private cooldowns: Map<string, number> = new Map();
  
  initPool(allCards: any[], state: any) {
    this.bag = allCards.filter(c => this.canAppear(c, state));
    this.calculateWeights(state);
  }
  
  canAppear(card: any, state: any): boolean {
    if (card.realmRequirement !== 'ANY' && card.realmRequirement !== state.realm) return false;
    if (card.maxAppearances && this.getAppearanceCount(card.cardId) >= card.maxAppearances) return false;
    if (card.prerequisites?.requiredTags) {
      for (let t of card.prerequisites.requiredTags) {
        if (!state.tags.includes(t)) return false;
      }
    }
    if (card.prerequisites?.exclusiveBuild && card.prerequisites.exclusiveBuild !== state.build) return false;
    if (this.cooldowns.get(card.cardId) > 0) return false;
    return true;
  }
  
  calculateWeights(state: any) {
    // 功法权重加成
    for (let card of this.bag) {
      card.currentWeight = card.baseWeight;
      if (state.build === 'SWORD' && card.karmaTags?.includes('剑')) {
        card.currentWeight *= 1.3;
      }
      // 福缘影响：高福缘稀有卡权重提升
      if (state.fortune >= 80 && card.karmaTags?.includes('机缘')) {
        card.currentWeight *= 2;
      }
    }
  }
  
  drawCard(state: any): any {
    // 重新计算可出现的卡
    this.bag = this.bag.filter(c => this.canAppear(c, state));
    this.calculateWeights(state);
    
    const total = this.bag.reduce((sum, c) => sum + c.currentWeight, 0);
    let r = Math.random() * total;
    for (let card of this.bag) {
      r -= card.currentWeight;
      if (r <= 0) {
        this.setCooldown(card.cardId, card.cooldownAfterPick || 0);
        return card;
      }
    }
    return this.bag[0];
  }
  
  setCooldown(cardId: string, turns: number) { this.cooldowns.set(cardId, turns); }
  tickCooldowns() {
    this.cooldowns.forEach((v, k) => { if (v > 0) this.cooldowns.set(k, v - 1); });
  }
  getAppearanceCount(cardId: string): number { return 0; /* 实际记录 */ }
}
```

### 4. CardUI.ts（卡牌滑动交互）

```typescript
import { _decorator, Component, Node, Vec3, EventTouch, tween, UIOpacity, UITransform } from 'cc';
const { ccclass, property } = _decorator;

export enum SwipeDir { LEFT, RIGHT, UP, DOWN }

@ccclass('CardUI')
export class CardUI extends Component {
  @property(Node) contentNode: Node = null;
  
  private startPos: Vec3 = new Vec3();
  private isDragging = false;
  private onSwipeCallback: (dir: SwipeDir) => void = null;
  
  setCardData(cardData: any) {
    // 设置卡牌文本、背景图
  }
  
  setOnSwipe(callback: (dir: SwipeDir) => void) {
    this.onSwipeCallback = callback;
  }
  
  onLoad() {
    this.node.on(Node.EventType.TOUCH_START, this.onTouchStart, this);
    this.node.on(Node.EventType.TOUCH_MOVE, this.onTouchMove, this);
    this.node.on(Node.EventType.TOUCH_END, this.onTouchEnd, this);
    this.node.on(Node.EventType.TOUCH_CANCEL, this.onTouchEnd, this);
  }
  
  onTouchStart(e: EventTouch) {
    this.isDragging = true;
    this.startPos = e.getUILocation();
  }
  
  onTouchMove(e: EventTouch) {
    if (!this.isDragging) return;
    const pos = e.getUILocation();
    const dx = pos.x - this.startPos.x;
    const dy = pos.y - this.startPos.y;
    this.node.setPosition(dx * 0.5, dy * 0.5, 0);
    this.node.setRotationFromEuler(0, 0, -dx * 0.05);
  }
  
  onTouchEnd(e: EventTouch) {
    this.isDragging = false;
    const pos = e.getUILocation();
    const dx = pos.x - this.startPos.x;
    const dy = pos.y - this.startPos.y;
    const threshold = 80;
    
    let dir: SwipeDir = null;
    if (Math.abs(dx) > Math.abs(dy)) {
      if (dx > threshold) dir = SwipeDir.RIGHT;
      else if (dx < -threshold) dir = SwipeDir.LEFT;
    } else {
      if (dy > threshold) dir = SwipeDir.UP;
      else if (dy < -threshold) dir = SwipeDir.DOWN;
    }
    
    if (dir !== null && this.onSwipeCallback) {
      this.onSwipeCallback(dir);
      this.animateOut(dir);
    } else {
      // 复位
      tween(this.node).to(0.2, { position: new Vec3(0, 0, 0), eulerAngles: new Vec3(0, 0, 0) }).start();
    }
  }
  
  animateOut(dir: SwipeDir) {
    const x = dir === SwipeDir.RIGHT ? 600 : dir === SwipeDir.LEFT ? -600 : 0;
    const y = dir === SwipeDir.UP ? 800 : dir === SwipeDir.DOWN ? -800 : 0;
    tween(this.node).to(0.25, { position: new Vec3(x, y, 0), eulerAngles: new Vec3(0, 0, x * 0.1) })
      .call(() => { this.node.destroy(); }).start();
  }
}
```

---

## 六、UI场景搭建流程

### 1. 创建主游戏场景

1. 在 `assets/scenes` 右键 → 新建场景 → `Game.scene`
2. 双击打开 `Game.scene`
3. 添加节点（在层级管理器右键 → 创建节点）：
   - **Canvas**（默认已创建）
     - **Background**（Sprite）→ 背景图
     - **CardLayer**（空节点）→ 卡牌容器
       - 实例化 `Card.prefab`
     - **TopBar**（空节点）→ 顶部状态
       - 境界显示（Label）
       - 功法显示（Label）
       - 灵石/寿元（Label）
     - **AttributeBars**（空节点）→ 五维属性条
       - 5个 `AttributeBar.prefab` 实例（修为、道心、善因、恶因、福缘、气血）
     - **ResourceSlots**（空节点）→ 丹药槽、法宝槽、道侣槽
     - **TianjiPanel**（空节点）→ 天机盘按钮
     - **EffectLayer**（空节点）→ 粒子特效
4. 把 `GameManager` 脚本挂到 Canvas 上

### 2. 制作Card.prefab

1. 在 `assets/prefabs` 右键 → 新建预制体 → `Card.prefab`
2. 双击编辑预制体
3. 内部结构：
   - **CardRoot**（空节点）
     - **bg**（Sprite）→ 卡牌背景
     - **title**（Label）→ 标题
     - **description**（Label）→ 描述文本
     - **leftHint**（Label）→ 左滑提示
     - **rightHint**（Label）→ 右滑提示
     - **upHint**（Label）→ 上滑提示（可选）
     - **downHint**（Label）→ 下滑提示（可选）
     - **karmaMark**（Sprite）→ 因果回溯标记
     - **yuanshenBtn**（Button）→ 元神选项按钮（可选）
4. 挂 `CardUI.ts` 脚本到 CardRoot
5. 把 title/description 等节点拖到脚本对应 @property 上

### 3. 属性条 AttributeBar.prefab

1. 新建预制体 `AttributeBar.prefab`
2. 结构：
   - 底槽（Sprite，灰色）
   - 填充条（Sprite，颜色根据属性：修为蓝、道心紫、善因金、恶因红、福缘绿、气血橙）
   - 数值Label
3. 挂脚本：

```typescript
@ccclass('AttributeBar')
export class AttributeBar extends Component {
  @property(Node) fillNode: Node = null;
  @property(Label) valueLabel: Label = null;
  
  setValue(current: number, max: number) {
    const p = current / max;
    this.fillNode.setScale(p, 1, 1);
    this.valueLabel.string = `${Math.floor(current)}/${max}`;
  }
}
```

---

## 七、数据管线：JSON怎么组织

### 1. 按境界分文件

在 `assets/gameData/cards/` 下创建：

```
cards/
├── qi_condensation.json      # 炼气期
├── foundation_building.json  # 筑基期
├── golden_core.json          # 金丹期
├── nascent_soul.json         # 元婴期
├── deity_transformation.json # 化神期
├── tribulation.json          # 渡劫
└── dungeon.json              # 秘境专属
```

### 2. 单文件格式

```json
{
  "realm": "QI_CONDENSATION",
  "cards": [
    {
      "cardId": "event_qi_001",
      "cardType": "NORMAL",
      "realmRequirement": "QI_CONDENSATION",
      "baseWeight": 100,
      "karmaTags": ["入门"],
      "content": {
        "title": "初入山门",
        "description": "一位须发皆白的老道拦住你的去路："小友灵根尚可，可愿拜入青云门？""
      },
      "decisions": {
        "LEFT": {
          "text": "拒绝独行",
          "statChanges": { "cultivation": 5, "dao": 5, "fortune": -10 },
          "addedTags": ["lone_cultivator"]
        },
        "RIGHT": {
          "text": "拜师入门",
          "statChanges": { "cultivation": 10, "dao": -5, "fortune": 10 },
          "addedTags": ["sect_member"],
          "generatedKarmaSeeds": [
            { "seedId": "qingyun_sect", "delayTurns": 15, "type": "GOOD" }
          ]
        }
      }
    }
  ]
}
```

### 3. 配置表 config.json

```json
{
  "realmOrder": ["QI_CONDENSATION", "FOUNDATION_BUILDING", "GOLDEN_CORE", "NASCENT_SOUL", "DEITY_TRANSFORMATION", "TRIBULATION"],
  "realms": {
    "QI_CONDENSATION": { "name": "炼气", "breakthroughCultivation": 100, "breakthroughDao": 30 },
    "FOUNDATION_BUILDING": { "name": "筑基", "breakthroughCultivation": 100, "breakthroughKarma": 50 }
  },
  "builds": {
    "SWORD": { "name": "剑修", "cardWeightBonus": 0.3 },
    "LAW": { "name": "法修", "multiDirChance": 0.15 }
  }
}
```

---

## 八、AI美术工作流接入Cocos

### 1. 美术资产清单与规格

| 资产 | 尺寸建议 | 格式 | 命名规范 |
|------|----------|------|----------|
| 卡牌背景 | 720×1280 | png | card_bg_qi_01.png |
| 角色立绘 | 512×512 透明底 | png | char_white_fox.png |
| 法宝图标 | 128×128 | png | artifact_qingfeng_sword.png |
| UI按钮 | 按需 | png | ui_btn_confirm.png |
| 属性条颜色 | 32×32 | png | ui_bar_cultivation.png |

### 2. AI生成流程

1. **Midjourney/Stable Diffusion 跑概念** → 确定画风（水墨/国风/像素）
2. **训练LoRA** → 用定调图训练风格模型，确保统一
3. **ComfyUI批量生成** → 按清单批量出图
4. **RMBG去背景** → 角色立绘透明底
5. **Photoshop精修** → 主角、关键道侣、Boss精修
6. **导入Cocos** → 拖进 `assets/resources` 对应目录

### 3. Cocos里自动关联图片

卡牌JSON里加 `backgroundImage` 字段：

```json
{
  "cardId": "event_qi_001",
  "backgroundImage": "cards/card_bg_qi_01",
  "characterImage": "characters/char_old_daoist"
}
```

代码中动态加载：

```typescript
resources.load(cardData.backgroundImage, SpriteFrame, (err, frame) => {
  this.bgSprite.spriteFrame = frame;
});
```

---

## 九、关键系统逐步实现顺序

### 阶段1：可滑动卡牌（第1-2天）

1. 创建项目，搭场景，做Card.prefab
2. 写 CardUI 滑动逻辑
3. 写 CardDataManager 加载3张测试卡
4. 游戏循环：抽卡 → 显示 → 滑动 → 应用效果 → 下一张卡
5. 加五维属性条显示

### 阶段2：死亡/转世（第3天）

1. 死亡检测（修为/道心/气血/寿元归零）
2. 转世界面：选择保留1个道基
3. 重置状态，新一局开始

### 阶段3：境界与突破（第4-5天）

1. 修为满触发突破
2. 简单版瓶颈：连续3张固定卡，成功就突破
3. 境界切换时改变卡池

### 阶段4：因果系统（第6-7天）

1. 滑动时生成因果种子
2. 延迟发芽成事件卡
3. 宿命卡转世后出现

### 阶段5：功法Build（第8-10天）

1. 炼气→筑基选功法
2. 功法专属卡牌加入卡池
3. 功法升级树（最简单：用计数器，同类卡用3次升级）

### 阶段6：资源与道具（第11-12天）

1. 灵石、丹药、法宝系统
2. 丹药栏、法宝栏UI
3. 丹药预使用

### 阶段7：渡劫Boss战（第13-15天）

1. 限时滑动（每张卡1.5秒）
2. 9张天劫卡链
3. 失败/成功处理

### 阶段8：秘境/多方向/元神（第16-20天）

1. 秘境入口卡和节点地图
2. 多方向滑动卡
3. 元神选项按钮

### 阶段9：结局/Meta（第21-25天）

1. 结局判定
2. 轮回图鉴
3. Meta解锁（灵根/称号）

### 阶段10：打磨/上架（第26-35天）

1. 音效、粒子、震动
2. 存档系统
3. 适配手机分辨率
4. TapTap打包测试
5. 上架材料准备

---

## 十、Cocos打包TapTap APK流程

### 1. 构建发布

1. 菜单 → **项目** → **构建发布**
2. 选择 **Android**
3. 配置：
   - 包名：com.yourstudio.yinianxiantu
   - 屏幕方向：Portrait（竖屏）
   - 目标API：34
   - 是否调试：首次打包选Debug，发布选Release
4. 点击构建

### 2. 签名（Release必需）

1. 下载安装JDK（如果还没装）
2. 用 `keytool` 生成签名：
   ```bash
   keytool -genkey -v -keystore my-release-key.keystore -alias yinianxiantu -keyalg RSA -keysize 2048 -validity 10000
   ```
3. 在Cocos构建面板里配置签名文件路径

### 3. 测试APK

1. 构建完成后，用USB连安卓手机
2. 打开开发者模式 → USB调试
3. 用 adb 安装：
   ```bash
   adb install build/android/proj/build/outputs/apk/release/yinianxiantu-release.apk
   ```

### 4. 上传TapTap

1. 注册TapTap开发者账号 https://developer.taptap.cn/
2. 创建游戏，填资料
3. 上传APK + 截图 + 宣传图 + 简介
4. 提交审核（通常3-7个工作日）

---

## 十一、MVP砍 scope 建议

你不是要一次做完459张卡。首测版本只验证核心循环：

| 功能 | 首测必须？ | 说明 |
|------|-----------|------|
| 滑动卡牌 | ✅ | 核心玩法 |
| 五维属性 | ✅ | 死亡机制 |
| 境界系统（炼气→筑基） | ✅ | 验证飞升感 |
| 死亡/转世 | ✅ | Roguelike核心 |
| 功法选择 | ✅ | 只加剑修/法修2种 |
| 因果种子 | ✅ | 1-2个简单因果链 |
| 丹药/法宝 | ⚠️ | 可先砍掉，只保留属性 |
| 秘境 | ❌ | 后续版本 |
| 多方向滑动 | ❌ | 后续版本 |
| 元神分身 | ❌ | 后续版本 |
| 渡劫限时 | ⚠️ | 可以简化成非限时 |
| 多结局 | ⚠️ | 先做2个结局 |

**首测目标：30-50张卡，1-2个功法，炼气→筑基循环，验证"滑动是否好玩、死亡是否愿意再来一局"。**

---

## 十二、推荐的下一步

1. **今天**：下载Cocos Creator 3.8，创建空项目，把Card.prefab做出来
2. **明天**：把3张测试卡写进JSON，做出"抽卡→滑动→属性变化"的最小循环
3. **后天**：加入死亡和转世，让游戏能真正"一局结束再来一世"
4. **一周后**：扩展炼气期到20-30张卡，加入功法选择

等你把最小循环跑起来，再往GDD里那些复杂系统（秘境、元神、多方向）上堆。

---

> 附：这个流程里的代码都是可直接用的骨架，但具体参数、资源路径、动画细节需要按你的项目名和美术资源调整。需要我直接按这个结构把前3天要写的完整代码都生成出来，就告诉我。
