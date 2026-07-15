# 角色美术技术规格书
## 像素光照渲染管线（Lit Pixel Pipeline）

---

## 一、核心美术方向：像素光照渲染

### 1.1 为什么不用纯平面像素

平面像素角色在移动端小屏幕上缺乏立体感，无法产生情感投射。玩家需要看到：
- 光照下的面部轮廓 → 情感共鸣点
- 衣料材质差异 → 角色辨识度
- 阴影下的眼神变化 → 剧情感

**解决方案**：像素精灵 + 法线贴图（Normal Map）+ 动态光照 Shader

### 1.2 技术原理

```
渲染管线：
  BaseColor贴图（像素精灵本体） × 动态光方向 × NormalMap解码
  + 金属度/粗糙度（MaterialMap R通道=粗糙度 G通道=金属度）
  + RimLight（边缘光，1-px宽，角色轮廓增强）
  = 有立体感的像素角色
```

参考对象：
- Dead Cells（3D模型转2D精灵，重）
- Hyper Light Drifter（纯像素 + 后期Bloom，轻但平）
- **我们的方案**：取两者之间——像素精灵 + 法线光照，移动端 < 2ms/frame

---

## 二、角色资产规格（Asset Budget）

### 2.1 角色精灵（In-Game Sprite）

| 参数 | NPC 立绘 | 小怪 | Boss |
|------|----------|------|------|
| 精灵尺寸 | 256×320 | 96×96 | 320×400 |
| 法线贴图 | 128×160 | 48×48 | 160×200 |
| 材质贴图 | 64×80 | 24×24 | 80×100 |
| 精灵方向 | 4方向（↑↓←→） | 2方向 | 4方向 |
| 单角色资产体积 | ~350KB | ~40KB | ~600KB |

### 2.2 UI 立绘（Dialogue Portrait）

| 参数 | 规格 |
|------|------|
| 尺寸 | 512×768（游戏内显示 256×384） |
| 格式 | PNG / WebP |
| 风格 | 像素光照渲染，半身像 |
| 表情变体 | 默认/微笑/悲伤/愤怒 × 3-4 表情 |
| 单角色体积 | ~500KB（含所有表情） |

### 2.3 8 NPC 总资产预算

| 角色 | 精灵（4向） | UI立绘 | 总预算 |
|------|------------|--------|--------|
| 白刃真人 | 350KB | 500KB | 850KB |
| 白落霜 | 350KB | 500KB | 850KB |
| 剑灵儿 | 350KB | 500KB | 850KB |
| 慕青岚 | 350KB | 500KB | 850KB |
| 殷血 | 350KB | 500KB | 850KB |
| 九尾溯月 | 350KB | 500KB | 850KB |
| 天机老人 | 350KB | 500KB | 850KB |
| 血煞老祖 | 350KB | 500KB | 850KB |
| **合计** | **2.8MB** | **4.0MB** | **6.8MB** |

> 移动端首次加载控制在 7MB 以内，使用纹理图集（Texture Atlas）减少 Draw Call

---

## 三、角色美术设计规范

### 3.1 女角色设计原则（核心）

三条硬标准，确保角色"让人想多看两眼"：

**1. 面部必须精致**
- 眼睛：至少 8×6 px 的瞳孔区域，高光点单独控制
- 鼻梁：1-2 px 宽的高光线（法线贴图实现）
- 嘴唇：1 px 的下唇高光（不用全涂满）
- 禁止：火柴人式五官、emoji 圆脸

**2. 发型决定辨识度**
- 白落霜：银白长发 + 右侧狐耳饰，发尾渐变淡蓝
- 慕青岚：深褐盘发 + 墨笔发簪，松散几缕垂落
- 殷血：黑长直 + 一道血红挑染，刘海遮半眼
- 九尾溯月：银白瀑发 + 狐耳，发丝间飘灵力粒子

**3. 冷暖对比 = 情感张力**
- 冷色调角色（白落霜、九尾）→ 月光/青蓝色 rim light，高冷但脆弱
- 暖色调角色（慕青岚）→ 灯笼暖光，温和但藏着秘密
- 暗色调角色（殷血）→ 血红 rim light，危险但渴望被理解

### 3.2 各角色配色方案

| 角色 | 主色 | 辅色 | 高光/Rim | 材质关键词 |
|------|------|------|----------|-----------|
| 白刃真人 | #E8E0D0 月白 | #C4A97D 淡金 | #FFF8E7 暖白 | 丝绸、剑锋反光、沧桑肌理 |
| 白落霜 | #D4E6F1 霜白 | #8FA4C0 冰蓝 | #E8F4FD 冷月白 | 丝缎、银饰、狐毛柔软感 |
| 剑灵儿 | #F0E6D3 练功白 | #D4956A 赤铜 | #FFF0E0 | 棉麻粗布、金属护腕、汗水光泽 |
| 慕青岚 | #8BA89A 书卷青 | #5C4033 古墨棕 | #E8D5B7 暖纸黄 | 粗纸纤维、墨迹润泽、木纹 |
| 殷血 | #1A0A0F 凝血黑 | #8B1A1A 深血红 | #FF2D2D 刀刃红 | 丝绸(黑)、皮革、血液润泽 |
| 九尾溯月 | #C8C0E0 月光银 | #DAA520 妖金瞳 | #E8E0FF 灵光白 | 透纱、九尾绒毛、灵力粒子 |
| 天机老人 | #5C5C6E 道袍灰 | #2A2A3E 玄夜深 | #A0A0C0 | 旧麻布、铜锈星盘、皱纹沟壑 |
| 血煞老祖 | #3A0008 血渊红 | #1A0000 深渊黑 | #FF4500 煞气橙 | 血纹战甲、骨饰、伤疤光泽 |

---

## 四、Shader 方案

### 4.1 Lit Pixel Shader（移动端核心 Shader）

```hlsl
// Lit Pixel Shader — 像素精灵 + 法线贴图 + 动态光照
// 用于: NPC 精灵、怪物、Boss
// 目标性能: < 1.5ms @ 移动端
Shader "Custom/LitPixel"
{
    Properties
    {
        _MainTex ("Base Color (Pixel Art)", 2D) = "white" {}
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _MaterialMap ("R=粗糙度 G=金属度 B=自发光", 2D) = "black" {}
        
        [Header(Lighting)]
        _LightDir ("主光方向 (世界空间)", Vector) = (0.5, 0.8, 1.0, 0)
        _LightColor ("主光颜色", Color) = (1, 0.98, 0.92, 1)
        _AmbientColor ("环境光颜色", Color) = (0.12, 0.15, 0.22, 1)
        
        [Header(Rim Light)]
        _RimColor ("边缘光颜色", Color) = (0.5, 0.7, 1.0, 1)
        _RimPower ("边缘光强度", Range(0.5, 4)) = 2.0
        _RimWidth ("边缘光宽度", Range(0, 1)) = 0.3
        
        [Header(Pixel Precision)]
        _PixelScale ("像素缩放", Range(1, 8)) = 2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            // Vertex Shader — 标准 MVP 变换 + UV
            // Fragment Shader — 核心逻辑:
            
            // 1. 采样 NormalMap，解码法线
            float3 normal = UnpackNormal(tex2D(_NormalMap, i.uv));
            
            // 2. 计算 Lambert 漫反射
            float NdotL = saturate(dot(normal, _LightDir));
            
            // 3. 采样 MaterialMap
            float3 material = tex2D(_MaterialMap, i.uv).rgb;
            float roughness = material.r;
            float metallic = material.g;
            float emission = material.b;
            
            // 4. 组合 BaseColor
            float4 baseColor = tex2D(_MainTex, i.uv);
            
            // 5. 漫反射 + 环境光
            float3 diffuse = baseColor.rgb * _LightColor.rgb * NdotL;
            float3 ambient = baseColor.rgb * _AmbientColor.rgb;
            
            // 6. 金属度反射（简化，移动端不用 PBR）
            float3 specular = _LightColor.rgb * metallic * 0.25;
            
            // 7. Rim Light（边缘光 — 角色轮廓增强）
            float rim = 1.0 - saturate(dot(normal, float3(0, 0, 1)));
            rim = smoothstep(1.0 - _RimWidth, 1.0, rim);
            float3 rimLight = _RimColor.rgb * rim * _RimPower;
            
            // 8. 自发光
            float3 emissionLight = baseColor.rgb * emission * 0.5;
            
            // 9. 最终组合
            float3 finalColor = diffuse + ambient + specular + rimLight + emissionLight;
            
            return float4(finalColor, baseColor.a);
            
            ENDHLSL
        }
    }
}
```

### 4.2 移动端优化要点

- **法线贴图**：64×64 → 128×128，BC5 压缩（移动端 ASTC 6×6）
- **MaterialMap**：三通道合一，一条纹理采样
- **无 PBR**：不用 GGX/BRDF，用简化 Lambert + 固定 specular
- **Rim Light**：只有 1 pass 的额外计算，成本极低（~0.1ms）
- **顶点级**：方向光方向传 uniform，不用逐像素重建

---

## 五、角色情感设计方法论

### 5.1 让玩家"喜欢上"角色的三要素

**1. 脆弱性暗示**
> 白落霜——冷艳外表下的狐族孤儿，月圆之夜独坐山崖。立绘设计时：正面冷但眼角微垂，嘴唇不是上扬而是抿住。右眼下方有一颗不在设定里写的小泪痣——画家自己加的。

**2. 角色独有的 小动作**
> 慕青岚推眼镜时总用指节而非指尖——这是她小时候怕戳破书页养成的习惯。立绘里的一只手微微抬起，手指弯曲，暗示这个动作。

**3. 台词与表情的微妙错位**
> 殷血说"我不需要任何人"时，嘴角在笑，但眉毛是平的。这种不协调让玩家感到"她在说谎"→ 产生想要了解她的欲望。

### 5.2 立绘表情系统

每个角色 4 种表情 + 1 个核心情感锚点：

| 角色 | 默认 | 微笑 | 悲伤 | 愤怒 | 情感锚点 |
|------|------|------|------|------|----------|
| 白落霜 | 冷·疏离 | 偶然·融化（嘴角微动） | 月夜·脆弱（眼睫下垂） | 护犊·锋利（瞳孔缩小） | **月下独坐的孤独感** |
| 慕青岚 | 专注·翻阅 | 发现·惊喜（眼镜反光） | 禁忌·恐惧（抿嘴） | 被冒犯·冷峻（推眼镜） | **藏书的秘密重量** |
| 殷血 | 冷漠·审视 | 讥诮·玩味（歪头） | 从未被展示 | 嗜血·兴奋（瞳孔放大、红瞳发光） | **渴望被接纳但不会说** |
| 九尾溯月 | 上古·平静 | 玩味·挑逗（狐尾微动） | 太古·哀伤（九尾低垂） | 威严·震慑（九尾炸开） | **三千年前的遗憾** |

---

## 六、制作流程（Production Pipeline）

### Phase 1: 概念设计（当前阶段）

- [x] 风格方向确定：像素光照渲染
- [x] AI 生成角色概念参考（白落霜、慕青岚、殷血 ✓）
- [ ] 每个角色完成手绘线稿确认（基于 AI 参考细化）
- [ ] 配色方案锁定（见 3.2 节）

### Phase 2: 精灵制作

1. 256×320 基础像素精灵（Aseprite / Photoshop）
2. 灰度高度图 → NormalMap 自动生成（Substance Designer / SpriteIlluminator）
3. MaterialMap 手动绘制（粗糙度 + 金属度 + 自发光）
4. 4 方向旋转 + 镜像（不重绘，Ctrl+Shift+F 翻转 + 微调）
5. 精灵图集打包（TexturePacker，整张 2048×2048）

### Phase 3: 立绘制作

1. 512×768 半身立绘（参考 AI 概念图，手绘精细）
2. 4 种表情变体（面部分层绘制，切换图层即可）
3. WebP 压缩（质量 85%，~250KB/角色）

### Phase 4: 引擎集成

1. Lit Pixel Shader 导入 + 参数调优
2. 精灵放入场景，四方向 Idle + Walk 动画（3帧循环）
3. UI 立绘挂载到对话系统
4. 移动端性能测试（< 2ms GPU time）

---

## 七、移动端性能预算

| 项目 | 预算 | 说明 |
|------|------|------|
| 同屏 NPC 上限 | 3 个 | 多场景不要同时出现超过 3 个带法线光照的 NPC |
| 单帧 GPU 时间 | < 16ms (60fps) | 角色渲染占 < 2ms |
| Draw Call（角色） | < 6 | 3 NPC × 1 图集 + 3 NPC × 1 NormalMap 图集 |
| 纹理内存 | < 50MB | 所有角色 + UI + 场景 + 卡牌插图 |
| 首次加载 | < 3s | 预加载角色图集到内存 |

---

## 八、参考图片索引

| 文件 | 内容 |
|------|------|
| `concept_bai_luoxuan.png` | 白落霜 — 银发、蓝眼、狐耳、白蓝丝袍、冷月 rim light |
| `concept_mu_qinglan.png` | 慕青岚 — 褐发盘髻、书卷青袍、纸灯暖光 |
| `concept_yin_xue.png` | 殷血 — 黑发红挑染、黑红血纹袍、刀刃红 rim light |

> 后续待生成：白刃真人、剑灵儿、九尾溯月、天机老人、血煞老祖

---

*文档版本: v1.0 | 作者: TechnicalArtist | 日期: 2026-06-27*
