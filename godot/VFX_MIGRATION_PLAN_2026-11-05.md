# 战斗特效重构方案 · 从网页逐帧切图到 Godot 原生特效体系

| 项 | 内容 |
|---|---|
| 文档版本 | v1.0（方案建议稿，未动任何代码） |
| 编制日期 | 2026-11-05 |
| 工程根 | `<repo>/godot` |
| 分析对象 | `content/assets/combat/vfx/`（148 目录 / 653 帧 / 29 MB）+ `content/data/combat/action_presentations.json` 的 `semanticVfx`（166 条） |
| 研究来源 | Genshin Impact 风格化 VFX 拆解（vfxapprentice）、像素战斗 FX 时序指南（gamineai）、GDQuest juicy attack 教程、Godot GPUParticles2D vs CPUParticles2D 对比、2D 弹幕游戏 shader 实践（flukz） |
| 性质 | **方案建议，不含实现**。所有数字标注口径 |

---

## 一、现状解剖：网页特效是怎么做的

### 1.1 三层结构【实测】

```
素材层   content/assets/combat/vfx/<fx_id>/frame-N.png
         148 个目录 / 653 张 PNG / 29 MB / 384×384 RGBA
              ↓ 路径数组
编排层   action_presentations.json → semanticVfx（166 条）
         { id, frames: [...], durationMs: 340, artApproval, finalArtApproved }
              ↓ JS 定时换 <img>.src
播放层   浏览器 DOM 逐帧切换
```

### 1.2 关键数字【实测】

| 指标 | 数值 | 含义 |
|---|---|---|
| 语义特效条目 | 166 | 按 `semanticVfx` 键计数 |
| **每条帧数** | **164 条只有 4 帧，2 条 3 帧** | 帧数分布 `{4: 164, 3: 2}` |
| 单帧时长 | 340ms ÷ 4 帧 ≈ **85ms/帧 ≈ 12 fps** | 以 `durationMs: 340` 样例计 |
| 帧尺寸 | 384×384 RGBA | PNG 颜色类型 6（真彩+透明） |
| 命名契约 | `<主体>_<动作>_agc_n<批次>`，动作 ∈ {attack, skill, hurt, defeat, impact, state} | 148 目录 |
| 接触帧 | `agc_w1_contact_profiles/<路径>/contact-1.png` | 每路径 1 帧 |
| 美术验收 | `finalArtApproved: false`（全 166 条） | 评审未通过即冻结 |

### 1.3 结构性不足

| # | 不足 | 具体表现 | 后果 |
|---|---|---|---|
| 1 | **帧数饿死** | 4 帧 / 340ms = 12fps，人眼在 16fps 以下感知为"幻灯片翻页"而非"运动" | 特效像贴图闪现，不像能量释放 |
| 2 | **只有播放没有合成** | 每个特效 = 一叠序列帧，无叠加、无混合模式、无光效分层 | 打击感单薄：现实中"重击"= 闪白+火花+震屏+减速四层同时 |
| 3 | **无游戏感层（juice）** | 网页 DOM 架构里没有 hit-stop、受击闪白、squash/stretch、屏幕震动的位置 | 打击"看得见"但"感觉不到" |
| 4 | **无程序化动态** | 4 帧之间是硬切，无插值、无速度曲线、无随机性 | 每次播放一模一样，重复攻击瞬间穿帮 |
| 5 | **方形贴图死板** | 384×384 正方形中心对齐，无方向性、无沿弧线的拉伸 | 斩击没有"从右上到左下"的方向语言 |
| 6 | **验收冻结** | 163 条 `finalArtApproved: false` | 任何基于这批素材的深度加工都会被返工 |

### 1.4 值得保留的部分（不要推倒）

| 资产 | 为什么好 |
|---|---|
| **语义分类** | 166 条特效按 `impact / contact / travel / target_state` 分 placement，这是「什么时候、在哪、播什么」的语义编排，**架构上是对的** |
| **命名契约** | `主体_动作_批次` 让 148 个目录可检索 |
| **接触帧（contact profiles）** | `body_palm_contact` 等按打击部位分类的单帧，正是"打击帧（impact frame）"的素材基础 |
| **RGBA 透明通道** | 384×384 帧是真彩+alpha，可直接进 Godot 的混合管线 |

**结论：保留语义层与素材，替换播放与合成层，新增 juice 层。**

---

## 二、为什么这套架构不适配 Godot

### 2.1 根本原因：引擎能力代差

| 能力 | 网页 DOM | Godot 4 |
|---|---|---|
| 帧动画 | JS 定时换 `img.src`，每帧一次 DOM 重绘 | `AnimatedSprite2D` / `SpriteFrames` 资源，引擎内插值播放 |
| 图像合成 | CSS `mix-blend-mode`（能力有限、性能差） | CanvasItem 4 种混合模式（add / sub / mul / premul alpha）+ 自定义 shader |
| 粒子 | 无原生粒子，需手写 canvas 循环 | `GPUParticles2D`（GPU 万级粒子）+ 子发射器 + 拖尾 + 湍流 |
| 全屏后处理 | 需 WebGL 手写 framebuffer | `ColorRect` + screen-space shader / `BackBufferCopy` |
| 时间控制 | `requestAnimationFrame` 粒度不稳 | `Engine.time_scale` 一行实现 hit-stop |
| 补间 | 手写 easing | 内置 `Tween` + 全套 easing 曲线 |

网页版不是"做不好"，是**根本没有这些原语**。它的架构是对 DOM 能力的合理适配——但这套适配在 Godot 里全是负资产：JSON 逐帧路径数组、JS 播放器、语义到 DOM 的映射层，在 Godot 里都是多余的中间层。

### 2.2 具体的不匹配点

| 网页实现 | Godot 里的正确对应 | 为什么必须换 |
|---|---|---|
| `frames: [路径数组]` + `durationMs` | `SpriteFrames` 资源（内建 fps、loop、帧事件） | JSON 路径数组要运行时 `load()`，散装 PNG 无图集 → 每帧一次纹理切换，无法合批 |
| JS 定时器切帧 | `AnimatedSprite2D.play()` 或 `AnimationPlayer` | JS 定时器与引擎帧循环不同步，会掉帧、会与 hit-stop 冲突 |
| CSS 叠加合成 | `CanvasItemMaterial.blend_mode = ADD` 等混合模式 | 特效的生命在于叠加发光，DOM 合成性能与表现双输 |
| 无粒子 | `GPUParticles2D` | 4 帧序列无法表达"火花四溅、余烬飘散"，这类内容本就该程序化生成 |
| 无 shader | CanvasItem shader（闪白、扭曲、溶解、色偏） | 打击闪白、护盾扭曲、死亡溶解是 shader 的本职工作 |
| `timeScale` 不存在 | `Engine.time_scale` | hit-stop 是战斗打击感的第一支柱，DOM 里做不了 |

### 2.3 一个重要的架构判断

**语义层（JSON 编排）应该保留并升级，播放层（帧序列+DOM）应该整体替换。**

理由：166 条 `semanticVfx` 的 `id / placement / durationMs` 编码了"哪个动作、打在哪、多长"的设计意图，这是策划资产；而逐帧路径数组只是当时 DOM 技术下的实现细节。换引擎时，**设计意图迁移，实现细节重写**。

---

## 三、Godot 原生重实现方案

### 3.1 目标架构：一个特效 = 一个场景，四层叠加

```
FxImpact.tscn (Node2D)
├─ SeqLayer        AnimatedSprite2D        序列帧打底（现有 4 帧素材，升到 24fps 感知）
├─ ParticleLayer   GPUParticles2D ×1~2     程序化增强（火花/余烬/碎片/光环）
├─ ShaderLayer     Sprite2D + ShaderMaterial  闪白 / 扭曲 / 溶解 / 色偏
└─ (juice 由宿主触发，不属于特效场景本体)
```

**每个特效一个 `.tscn`**，由 `FxLibrary` 按语义 id 实例化。166 条 semanticVfx 不需要 166 个手搓场景——按 **6 类动作 × 参数化模板**收敛：

| 动作类型 | 模板场景 | 序列帧层 | 粒子层 | shader 层 |
|---|---|---|---|---|
| `impact`（打击点） | `FxImpact.tscn` | contact 帧 + 白闪 | 火花迸射（锥形，one-shot） | 径向模糊 / 冲击波扭曲 |
| `attack`（攻击轨迹） | `FxTravel.tscn` | 帧序列沿弧线 | 拖尾粒子 | UV 拉伸（方向速度感） |
| `skill`（技能演出） | `FxSkill.tscn` | 帧序列 + 光柱 | 上升余烬 + 元素粒子 | 加法辉光 |
| `hurt`（受击） | `FxHurt.tscn` | 无帧（用 shader） | 少量碎屑 | **受击闪白**（本体） |
| `defeat`（消散） | `FxDefeat.tscn` | 帧序列反向 | 上升灰烬 | **溶解**（noise threshold） |
| `state`（状态光环） | `FxState.tscn` | 循环帧 | 持续环绕粒子 | 呼吸 alpha |

### 3.2 第一层：序列帧打底（让现有 4 帧活起来）

**问题**：4 帧 @12fps 是幻灯片。

**解法（三招叠加，无需重画素材）**：

1. **帧率重排**：4 帧按 `25% / 15% / 10% / 50%` 的不等时长分配（Godot `SpriteFrames` 支持每帧独立时长），模拟"快进慢出"的动画 spacing——冲击帧短、收尾帧长，这是 2D 动画的基本节奏原则
2. **程序化补间**：帧与帧之间用 shader 做位移/缩放插值（前帧放大淡出 + 后帧进入），4 帧素材获得 8~12 个视觉状态
3. **方向性**：`Node2D.rotation` 由攻击方向驱动（384 方形帧旋转到攻击角度），加 `scale.x = -1` 镜像，同一素材覆盖 8 方向

**帧率感知对比**：4 帧@85ms 均分 = 幻灯片；4 帧不等时长 + 插值 + 旋转 = 可读的打击动作。

### 3.3 第二层：GPUParticles2D（程序化增强）

项目是 **Forward+ 桌面端**，直接用 `GPUParticles2D`（Web 导出才需要降级 `CPUParticles2D`，当前平台范围不含 Web 手机的低端兼容，保留切换预案即可）。

**每个动作类型的粒子配方**（起步参数，后续按美术评审调）：

| 类型 | 发射形状 | 关键参数 | 参考数值 |
|---|---|---|---|
| impact 火花 | 锥形，沿法线 | `one_shot=true, explosiveness=1.0, amount=12~24, lifetime=0.3s` | 初速 400~800，重力 900，scale curve 快缩 |
| travel 拖尾 | 点发射 + `local_coords=false` | `amount=30, lifetime=0.5s` | 沿轨迹留残影，add 混合 |
| skill 余烬 | 盒形区域 | `amount=20, lifetime=1.2s` | 上升重力 -150，颜色 ramp 亮→暗 |
| defeat 灰烬 | 全身盒形 | `amount=40, lifetime=1.5s` | 上升 + 湍流 + alpha 渐隐 |
| state 光环 | 环形表面 | `amount=16, lifetime=1s, loop` | 环绕速度用切向初速 |

**子发射器**：impact 火花死亡时喷出烟雾（`sub_emitter` 模式），一次配置两层效果。

**性能纪律**：
- 每特效同时在场粒子 ≤ 64；同屏特效 ≤ 3 组（超出时最旧的降级为纯序列帧）
- `visibility_rect` 必须手工设大（GPUParticles2D 按此矩形剔除，默认太小会"粒子消失"）
- 首次播放 shader 编译会卡一帧 → **加载屏预暖**：进场时对每类模板各 `restart()` 一次并立即隐藏

### 3.4 第三层：Shader 层（五个基础 shader 覆盖 80% 需求）

全部是 CanvasItem shader，参数驱动，一个 shader 服务所有特效实例（`instance uniforms` 避免材质克隆）：

| Shader | uniform | 用途 | 参考实现 |
|---|---|---|---|
| **HitFlash** | `flash_strength: float` | 受击闪白 1~2 帧 | `COLOR.rgb = mix(tex.rgb, vec3(1.0), strength)`；宿主在受击帧置 1.0，2 帧内衰减到 0 |
| **Dissolve** | `dissolve_progress: float` + noise 纹理 | defeat 消散 | `if (noise.r < progress) discard;` 边缘加发光带 |
| **RadialBlur** | `center, strength` | impact 冲击瞬间 | 4~6 次采样沿径向偏移混合 |
| **UVStretch** | `direction, stretch` | travel 方向速度感 | UV 沿方向拉伸 + 尾部 alpha 衰减 |
| **AddGlow** | 无（混合模式即可） | skill 光效 | `blend_add` + 双层绘制（放大低 alpha 模拟辉光，避免全屏 bloom 管线） |

**通道所有权纪律**（多系统叠加时的铁律，业界踩坑总结）：

| 通道 | 唯一拥有者 |
|---|---|
| 受击闪白 | FxHurt shader |
| hit-stop | 战斗域一个系统（`Engine.time_scale`） |
| 屏幕震动 | 一个 CameraShake 系统 |
| 溶解 | FxDefeat shader |

两个系统同时写 `time_scale` 或同一 sprite 两个 shader = 三天排查不出的大 bug。

### 3.5 第四层：Juice（打击感五件套）

特效本身只是画面，**打击感来自特效与时间、镜头、受击体的联动**。业界共识的分层清单（每层独立开关，逐层验证增益）：

| 层 | 实现 | 参数参考（60fps） |
|---|---|---|
| **Hit-stop** | `Engine.time_scale` 短暂压低 | 轻 2~4 帧（33~67ms）/ 中 3~5 帧 / 重击 6~10 帧（100~167ms）/ 暴击格挡 8~15 帧；**不要设 0**，用 0.05~0.1 保粒子继续动 |
| **Hit-flash** | 受击体 shader（§3.4 HitFlash） | 1~2 帧高对比，长了像眩晕 UI |
| **Squash & Stretch** | `Tween` 对受击体 scale | 打击轴压缩 0.85、垂直 1.1，80ms 弹回 |
| **Screen shake** | 相机偏移，幅度按伤害分级 | 轻击 1~3px 高频 / 爆炸 4~8px / Boss 10px+；方向性震动（沿打击法线）比随机更有 grounding |
| **Impact frame** | 全屏反色/白帧 1~2 帧 | 仅重击与终结技；shader 全屏反色一帧，Genshin 式"视觉重置" |

**与现有战斗系统的接线点**：`combat_domain` 结算命中 → `DeckCombatUI` 收到事件 → 按伤害分级触发五件套。语义层已有的 `contact frame` 时间点（`semanticVfx` 的 contact 帧）就是五件套的触发时刻。

### 3.6 风格支柱（美术方向，来自 Genshin 拆解的迁移）

| 支柱 | 对本项目的落地 |
|---|---|
| **硬边矢量轮廓** | 新特效贴图用硬边剪影，不用柔和烟雾渐变——与现有水墨+PC-98 风格一致，且 4 帧素材上叠加软粒子会糊 |
| **手绘纹理粒子** | 粒子贴图用毛笔笔触/符纸/灵光等手绘形状（现 assets 里已有水墨风格素材可裁切），不用默认白点 |
| **大胆元素色** | 五修路各定一个高对比主色（剑=青、法=紫、体=赭、丹=橙、器=金），特效全部走元素色，玩家看颜色即知修路 |
| **动画式 timing** | 帧不等时长（§3.2）+ hit-stop + 预备帧，模拟手绘动画的 spacing |

---

## 四、升级迭代路线（四批，每批独立可验收）

### 批次 V1｜地基（纯 Godot 侧，不动素材）

| 任务 | 验收 |
|---|---|
| `FxLibrary` 语义路由器：166 条 semanticVfx id → 6 个模板场景实例化 | 单元测试：166 条 id 全部能取到场景 |
| 6 个参数化模板场景（§3.1） | 每个模板 F6 独立可跑 |
| HitFlash shader + 受击接线 | 受击时闪白 1~2 帧，截图可证 |
| hit-stop 系统接线（伤害分级） | 轻重击 time_scale 曲线不同，录屏可证 |
| 加载屏 shader 预暖 | 首次战斗无 shader 编译卡顿 |

### 批次 V2｜粒子增强

| 任务 | 验收 |
|---|---|
| impact/travel/skill/defeat/state 五套粒子配方 | 每套参数表入库（.tres），美术可调 |
| 粒子贴图手绘化（水墨笔触裁切） | 无默认白点 |
| 子发射器（火花→烟） | 火花死亡喷烟 |
| 性能预算落地（同屏 ≤3 组、粒子 ≤64/组） | 压测：3 Boss 同屏 60fps |

### 批次 V3｜shader 扩展

| 任务 | 验收 |
|---|---|
| Dissolve / RadialBlur / UVStretch / AddGlow 四 shader | 各配 1 个特效实例验收 |
| Impact frame（全屏反色 1 帧） | 仅重击触发，录屏可证 |
| 方向性系统（rotation/镜像/UVStretch 接攻击方向） | 8 方向攻击特效方向正确 |

### 批次 V4｜素材升级（依赖美术）

| 任务 | 验收 |
|---|---|
| 关键 20 个特效重绘为 8~12 帧（优先 Boss 技能） | 美术评审通过 |
| contact 帧扩充（每路径 3 帧：进入/峰值/衰减） | 打击更"脆" |
| `finalArtApproved` 流程走通 | 163 条 → 逐步转正 |

**依赖关系**：V1/V2/V3 纯代码，可立即做；V4 必须等美术评审（当前 163 条全部 `finalArtApproved: false`，评审前重绘=返工）。

---

## 五、风险与预算

| 风险 | 缓解 |
|---|---|
| GPUParticles2D 首次编译卡帧 | 加载屏预暖（§3.3） |
| `visibility_rect` 配小导致粒子消失 | 模板场景统一放大 rect，写进模板基类 |
| 特效与 hit-stop 时序冲突 | time_scale 单一拥有者；粒子用 `fixed_fps` 不受 time_scale 完全冻结 |
| 4 帧素材被插值后边缘发糊 | 插值强度可调；不满意退回纯帧+粒子（无插值模式） |
| 同屏多 Boss 特效叠加超预算 | 特效组数上限 + 最旧降级策略 |
| 美术评审不通过导致 V4 返工 | V1~V3 与素材解耦，评审通过前只动代码层 |

**工作量粗估【推断，需实测校准】**：V1 约 2~3 天、V2 约 2 天、V3 约 2 天、V4 取决于美术排期。

---

## 六、不做的事

| 项 | 原因 |
|---|---|
| 全屏 Bloom 后处理管线 | per-sprite glow（双绘制）已够用，避免多 pass 渲染复杂度 |
| 3D 特效 mesh（Genshin 式曲面斩击） | 项目是 2D 舞台，成本收益不成比 |
| 每特效独立手搓场景 | 6 模板参数化收敛，166 条不手搓 |
| 评审前重绘帧序列 | 163 条全部未通过评审，现在画=返工 |
| Web 端 CPUParticles2D 双轨维护 | 平台范围仅 Windows 桌面；保留切换知识（§3.3），不做双实现 |

---

## 七、一句话总结

> **保留 166 条语义编排和 4 帧素材的"设计意图"，扔掉"DOM 切图"的实现方式；用「序列帧重排 + GPU 粒子 + 五 shader + 打击感五件套」四层体系，让 4 帧素材在 Godot 里活过来；素材重绘放在美术评审之后，代码层先跑通全链路。**

---

**文档版本**：v1.0  
**编制日期**：2026-11-05  
**性质**：方案建议，未动代码  
**下一步**：若采纳，从批次 V1 的 `FxLibrary` 语义路由器开始
