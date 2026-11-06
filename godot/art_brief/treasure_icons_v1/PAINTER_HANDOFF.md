# 法宝图标绘制对接单

> 这份文档自包含，读完即可开工。**18 张图，一张不多一张不少。**
> 规则详解与「其他素材为什么不用画」见同目录 `BRIEF.md`；
> 机器可读配置见 `manifest.json`（本文件由它渲染，两者内容一致）。

| 项 | 内容 |
|---|---|
| 项目 | 一念仙途 |
| 引擎 | Godot 4.7.2（运行时按 nearest 缩到 26×26 显示） |
| 用途 | 法宝装备弹窗列表行首图标，显示尺寸 26x26 |
| 数量 | **18 张**，覆盖 55 件法宝 |
| 生成日期 | 2026-11-06 |

---

## 一、你现在要做什么

画 **18 个独立的像素风小图标**，每个都是一件中国修仙题材的器物。
深色描边、全透明背景、无外框、无发光，缩到 26 像素还能一眼认出是什么东西。

**参照风格**：`godot/content/assets/icons/icon_lifespan.png`（64×64 像素图标）、
`godot/content/assets/icons/icon_linggen_huo.png`（64 网格像素画放大到 1024）。
这批新图必须是同一套语言——**是像素画，不是手绘插画，不是 3D 渲染**。

## 二、落盘位置（18 张全放同一个目录）

```
E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items
```

| 用途 | 路径写法 |
|---|---|
| 绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items` |
| 引擎内路径 | `res://content/assets/icons/items/` |
| 数据引用写法 | `assets/icons/items/` |
| 命名规则 | `{slot}_{rarity}.png` |

**文件名一个字都不能改**，代码按 `{槽位}_{品阶}` 拼路径。目录不存在就新建。

## 三、画布与输出规格（硬约束）

| 项 | 要求 |
|---|---|
| 画布 | **512 × 512 px** |
| 逻辑网格 | **64 × 64** |
| 单格大小 | **8 × 8 px** 实心块 |
| 抗锯齿 | **零**。alpha 只有 0 或 255，不允许任何半透明过渡像素 |
| 背景 | 完全透明，四角 alpha = 0 |
| 格式 | PNG，RGBA |

> 为什么是 512 / 64 / 8：512 = 64 × 8，所以每个逻辑像素正好 8×8 实心块。
> 缩到 26×26 时不会出现半像素和模糊。**不要输出 1024 或任何非 8 倍数的画布。**

## 四、画风硬约束

项目美术母语（摘自 `docs/ART_DIRECTION_BIBLE_v1.md`）：

> **水墨结构、PC98 像素颗粒、暗色命书、克制的修仙异象**

落到这批图标上：

| 维度 | 要求 |
|---|---|
| 技法 | 手绘像素画。硬边色块 + 受控抖色。禁止平滑喷枪、禁止羽化 |
| 描边 | 统一墨黑描边 #141A19，在 64 网格上为 1 像素宽；禁止无描边、禁止双色柔边 |
| 色数 | 单图 **不超过 16 色**（见品阶分级） |
| 背景 | 完全透明 |
| 外框 | **不画**边框、圆角徽章、卡片底、圆形底盘 |
| 光照 | 无发光、无 bloom、无边缘光、无镜头光斑。体积只靠色块明度差 |
| 构图 | 单一物件居中，占画布约 78%，四周留 6 逻辑像素安全区 |
| 可读性 | 缩到 **26×26** 仍能一眼分辨物件类别 |

**禁止进入画面**：文字、数字、品阶角标、水印、签名、人物、手、现代物件

### 调色板（只准用这些色）

| token | 色值 | 用途 |
|---|---|---|
| 墨 | `#141A19` | 描边、最深阴影 |
| 纸 | `#EEE5D1` | 亮面、布、纸 |
| 灰纸 | `#C9C3B4` | 铁、石、次级亮面 |
| 冷玉 | `#9FBCB1` | 玉、灵气、正道物件 |
| 旧金 | `#BDA77B` | 铜件、包角、环扣 |
| 深旧金 | `#8A7550` | 青铜暗部、木胎 |
| 朱砂 | `#B66C61` | **只用于危险/仙品点缀**，全图不超过一处 |
| 冷白 | `#F2F0E8` | 极少量高光，1~4 像素 |

### 品阶视觉分级（必须能一眼区分）

| 品阶 | 语言 |
|---|---|
| r2 | 凡品。只用墨 + 灰纸两色，无装饰件，轮廓最简。 |
| r3 | 灵品。加一种材质色（旧金或雾青），允许一处极简纹样。 |
| r4 | 真品。加一档高光，允许两道结构线，材质分层清晰。 |
| r5 | 玄品。允许一处朱砂或冷玉点缀，边缘可有一像素冷高光。 |
| r6 | 仙品。允许一点天金/冷白，纹样最繁复；仍禁止发光与粒子。 |

## 五、统一负向提示词（每张都要带）

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

---

## 六、逐项绘制指令

按槽位分组。每项含：落盘路径、画什么、可直接复制的正向 prompt、该张专项验收。

### 兵刃（5 张，覆盖 14 件法宝）

#### 01. `weapon_2.png`  · 凡品 r2

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/weapon_2.png` |
| 引擎路径 | `res://content/assets/icons/items/weapon_2.png` |
| 覆盖法宝 | 剑冢残剑（共 1 件） |
| 建议用色 | `#141A19`、`#C9C3B4` |

**画什么**：一柄从剑冢挖出的残破铁剑，剑身中段有明显缺口，表面锈斑，剑柄缠布已磨损。斜置 45 度，剑尖朝右上。整体朴素，不要纹饰。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, drawn on a 64x64 logical grid with hard 8px blocks and zero anti-aliasing. Subject: a broken ancient iron sword excavated from a sword tomb, a clear V-shaped chip missing from the middle of the blade, mottled rust patches, worn cloth-wrapped grip, tilted 45 degrees with the tip pointing upper-right. Plain and austere, no ornament. Chinese xianxia cultivation setting. One-pixel dark ink outline #141A19 on the grid, two-tone flat shading only (dark iron and pale weathered gray), no highlight, no glow. Object centered at about 78% of canvas with a 6-grid-pixel margin. Must stay readable when scaled to 26x26.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 64 网格对齐，无半透明过渡像素
- 色数 <= 8
- 缺口位置一眼可辨
- 缩到 26px 仍能认出是剑

#### 02. `weapon_3.png`  · 灵品 r3

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/weapon_3.png` |
| 引擎路径 | `res://content/assets/icons/items/weapon_3.png` |
| 覆盖法宝 | 剑心佩、坊市净炼残剑、集市易手残剑（共 3 件） |
| 建议用色 | `#141A19`、`#C9C3B4`、`#9FBCB1` |

**画什么**：一柄短剑与一枚小玉佩并置。短剑直立微斜，剑身有细密锻纹；玉佩系短绳挂在剑格旁，呈冷玉色。剑为主、佩为副。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: a short Chinese straight sword standing nearly upright with a slight lean, fine forge-fold lines along the blade, plus one small jade pendant on a short cord hanging beside the crossguard. Jade reads pale blue-green. Sword is primary, pendant secondary, both must not merge into one blob. Chinese xianxia setting. One-pixel ink outline #141A19, three-tone flat shading (dark iron, pale steel, jade #9FBCB1), one small specular block on the blade edge. Centered, 78% canvas, no frame, no glow.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 短剑与玉佩轮廓分离清晰
- 色数 <= 12
- 玉佩在 26px 下仍是一个可辨小点

#### 03. `weapon_4.png`  · 真品 r4

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/weapon_4.png` |
| 引擎路径 | `res://content/assets/icons/items/weapon_4.png` |
| 覆盖法宝 | 剑心古剑、血玉扳指、太古遗剑、夜契残剑（共 6 件） |
| 建议用色 | `#141A19`、`#C9C3B4`、`#BDA77B`、`#F2F0E8` |

**画什么**：一柄完整长剑直立居中，剑格为云纹造型，剑身笔直、开双血槽，刃口一线冷光。剑柄末端有旧金护环。这是最常出现的一张兵刃图标，要求结构最清晰。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: one complete Chinese straight sword standing perfectly vertical in the center, cloud-pattern crossguard, straight double-fullered blade, a single cold highlight line running down the edge, aged brass pommel ring. This is the most frequently used weapon icon, so structure must be unmistakable. Chinese xianxia setting. One-pixel ink outline #141A19, four flat tones (dark iron, steel gray, brass #BDA77B, one cold-white highlight), no gradient, no glow. Centered, 78% canvas, generous margin at the tip.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 剑格云纹在 64 网格上不超过 3 像素高
- 刃口高光为单一色块，不得渐变
- 色数 <= 14

#### 04. `weapon_5.png`  · 玄品 r5

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/weapon_5.png` |
| 引擎路径 | `res://content/assets/icons/items/weapon_5.png` |
| 覆盖法宝 | 炼妖壶、问道剑、白刃遗剑（共 3 件） |
| 建议用色 | `#141A19`、`#C9C3B4`、`#8A7550`、`#B66C61` |

**画什么**：长剑与前方的三足小壶组合，剑在壶后竖立，壶身圆鼓、有盖。剑身周围有一缕极简灵气（两三个像素点，不得成光晕）。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: a tall Chinese straight sword behind a small three-legged round earthen vessel with a lid, composition reads as one grouped object; sword vertical, vessel in front and slightly lower. Two or three single pixels of drifting qi above the vessel, no aura, no halo. Chinese xianxia setting. One-pixel ink outline #141A19, five flat tones (dark iron, steel, aged bronze, muted paper, cinnabar #B66C61 accent on the vessel rim only). Centered, 78% canvas, no frame.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 剑与壶轮廓不粘连
- 灵气为离散像素点，不得连成光晕
- 朱砂只出现在壶沿一处

#### 05. `weapon_6.png`  · 仙品 r6

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/weapon_6.png` |
| 引擎路径 | `res://content/assets/icons/items/weapon_6.png` |
| 覆盖法宝 | 破魂锥（共 1 件） |
| 建议用色 | `#141A19`、`#BDA77B`、`#B66C61`、`#F2F0E8` |

**画什么**：一支细长锥形法器，锥尖朝下，尖端一点朱砂色，锥身有螺旋刻纹，尾端加旧金环。周围散落三四个碎光点（单像素，非光晕）。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: one slender awl-shaped ritual implement pointing downward, spiral engraving wrapped around the shaft, aged brass collar at the blunt top, a single cinnabar pixel cluster at the very tip. Three or four isolated single-pixel sparks nearby, not connected. Chinese xianxia immortal-grade implement. One-pixel ink outline #141A19, six flat tones including brass #BDA77B, cinnabar #B66C61 and one cold-white #F2F0E8 sliver. Centered, 78% canvas, no frame, no bloom.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 锥尖朱砂不超过 3 个逻辑像素
- 碎光点为独立像素，不得连片
- 色数 <= 16

### 护具（4 张，覆盖 5 件法宝）

#### 06. `armor_2.png`  · 凡品 r2

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/armor_2.png` |
| 引擎路径 | `res://content/assets/icons/items/armor_2.png` |
| 覆盖法宝 | 玄铁甲（共 1 件） |
| 建议用色 | `#141A19`、`#C9C3B4` |

**画什么**：一件深灰铁片胸甲正面正视，无袖、无头盔，胸口有中脊，两侧各两颗铆钉。表面哑光，无装饰纹样。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: a sleeveless dark graphite iron torso cuirass viewed straight on, narrow vertical center ridge, two rivets on each side, matte finish, no ornamental engraving, no helmet, no pauldrons. Chinese xianxia low-grade armor. One-pixel ink outline #141A19, three flat tones of iron (dark, mid, one worn edge), no highlight, no glow. Centered, 78% canvas, symmetric silhouette.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 左右对称，误差不超过 1 逻辑像素
- 铆钉为单像素方块
- 色数 <= 8

#### 07. `armor_3.png`  · 灵品 r3

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/armor_3.png` |
| 引擎路径 | `res://content/assets/icons/items/armor_3.png` |
| 覆盖法宝 | 灵纹法袍（共 1 件） |
| 建议用色 | `#141A19`、`#EEE5D1`、`#9FBCB1` |

**画什么**：一件交领布制法袍的上半段，前襟左右交叠，衣缘有一道雾青色灵纹走线（细，不断开），袖口只画到上臂。布料质感，无金属件。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: the upper half of a crossed-collar cloth robe, left and right lapels overlapping, one thin continuous mist-jade embroidered line running along the collar edge, sleeves cropped at upper arm. Cloth texture only, no metal parts, no belt buckle. Chinese xianxia spirit-grade robe. One-pixel ink outline #141A19, four flat tones (dark cloth, mid cloth, pale paper lining, jade #9FBCB1 thread). Centered, 78% canvas, no glow.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 灵纹是连续单像素线，不得断成虚线
- 交领左右叠压关系可辨
- 色数 <= 12

#### 08. `armor_4.png`  · 真品 r4

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/armor_4.png` |
| 引擎路径 | `res://content/assets/icons/items/armor_4.png` |
| 覆盖法宝 | 天瀑雷纹甲、冰魄镜甲（共 2 件） |
| 建议用色 | `#141A19`、`#8A7550`、`#9FBCB1`、`#F2F0E8` |

**画什么**：一件带肩片的甲胄正面，胸口甲片分三层叠压，甲面刻简化雷纹（折线，三到四笔），边缘有一线冷色反光。肩片小而服帖，不夸张。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: a front-view plated cuirass with three overlapping horizontal lamellar bands, a simplified angular thunder pattern etched across the chest in three or four strokes, two small close-fitting shoulder caps (not oversized pauldrons), one cold reflective highlight along the left edge. No helmet, no cape. Chinese xianxia true-grade armor. One-pixel ink outline #141A19, five flat tones (iron dark, iron mid, worn steel, cold jade reflection #9FBCB1, paper highlight). Centered, 78% canvas, no glow.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 三层叠压有明确分界线
- 雷纹为折线，不得写成文字
- 肩片宽度不超过胸甲宽度的 1/4

#### 09. `armor_5.png`  · 玄品 r5

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/armor_5.png` |
| 引擎路径 | `res://content/assets/icons/items/armor_5.png` |
| 覆盖法宝 | 虚空袈裟（共 1 件） |
| 建议用色 | `#141A19`、`#8A7550`、`#9FBCB1`、`#F2F0E8` |

**画什么**：一件斜披的袈裟，布面呈半透明虚空感（用抖色表现通透，禁用真半透明），下摆边缘化为稀疏像素并有三四点星屑。领口有一道旧金滚边。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: a diagonally draped monk's kasaya robe whose lower hem dissolves into sparse scattered pixels with three or four single-pixel star flecks. Achieve the void/ethereal feel through controlled dithering of solid colors, NOT through real semi-transparent pixels. One aged-brass piping line along the collar. Chinese xianxia mystic-grade robe. One-pixel ink outline #141A19, five flat tones (deep cloth, mid cloth, dithered void, brass #BDA77B, cold white fleck). Centered, 78% canvas, no glow, no bloom.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 通透感由抖色实现，alpha 只有 0 或 255
- 下摆离散像素不少于 6 个且不连片
- 滚边为单像素线

### 佩饰（5 张，覆盖 12 件法宝）

#### 10. `accessory_2.png`  · 凡品 r2

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/accessory_2.png` |
| 引擎路径 | `res://content/assets/icons/items/accessory_2.png` |
| 覆盖法宝 | 灵泉葫芦、岩甲兽核（共 2 件） |
| 建议用色 | `#141A19`、`#BDA77B`、`#8A7550` |

**画什么**：一只掌心大小的双球葫芦，腰身明显收束，顶部小木塞，腰间系一根短绳，绳结垂下。葫芦呈暖褐色，素面。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: a palm-sized double-bulb gourd bottle with a visibly cinched waist, small dark cork on top, a short cord tied around the waist with two loose ends hanging. Warm honey-brown body, plain surface, no pattern. Chinese xianxia common-grade accessory. One-pixel ink outline #141A19, three flat tones of gourd (deep, mid, lit side), cord in dark ink. Centered, 78% canvas, no frame, no liquid, no splash.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 腰身收束清晰，双球比例约 1:1.4
- 绳子不超过 3 逻辑像素宽
- 色数 <= 10

#### 11. `accessory_3.png`  · 灵品 r3

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/accessory_3.png` |
| 引擎路径 | `res://content/assets/icons/items/accessory_3.png` |
| 覆盖法宝 | 避尘珠、万年玄冰（共 2 件） |
| 建议用色 | `#141A19`、`#9FBCB1`、`#BDA77B` |

**画什么**：一颗浑圆珠子居中，珠面有一个方形高光块，珠下一枚极小的旧金托座。整体冷玉色，素净。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: one perfectly round bead centered, a single square specular block on the upper-left of the sphere (not a gradient), sitting on a tiny aged-brass socket below. Pale jade body, clean and plain, no engraved pattern. Chinese xianxia spirit-grade bead. One-pixel ink outline #141A19, four flat tones (jade shadow, jade mid, jade light #9FBCB1, brass #BDA77B). Centered, 78% canvas, no glow.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 高光是单一色块，不得做成渐变球
- 圆形在 64 网格上不出现锯齿抖动
- 色数 <= 10

#### 12. `accessory_4.png`  · 真品 r4

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/accessory_4.png` |
| 引擎路径 | `res://content/assets/icons/items/accessory_4.png` |
| 覆盖法宝 | 无相空瓶、天枢罗盘、定魂玉、续命珠（共 5 件） |
| 建议用色 | `#141A19`、`#9FBCB1`、`#BDA77B`、`#EEE5D1` |

**画什么**：一块竖立玉牌与一个小罗盘叠置，玉牌在上、罗盘半露在下。玉牌中心一个方形留白（无相之意），罗盘面用十字与两圈刻度示意，刻度用单像素点。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: a vertically standing jade tablet overlapping a small compass dial below it; the tablet has a clean square void in its center, the dial shows a simple cross and two concentric tick rings drawn with single pixels. Jade tablet in front, compass half-hidden behind. Chinese xianxia true-grade accessory set. One-pixel ink outline #141A19, five flat tones (jade shadow, jade mid #9FBCB1, brass #BDA77B, dark dial, paper highlight). Centered, 78% canvas, no numerals, no letters.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 玉牌中心留白为纯镂空或纯底色，不放任何符号
- 罗盘刻度只用单像素点，不得写成数字
- 色数 <= 14

#### 13. `accessory_5.png`  · 玄品 r5

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/accessory_5.png` |
| 引擎路径 | `res://content/assets/icons/items/accessory_5.png` |
| 覆盖法宝 | 两仪环、因果镜（共 2 件） |
| 建议用色 | `#141A19`、`#BDA77B`、`#9FBCB1`、`#F2F0E8` |

**画什么**：两只细环上下相扣成一体，上环略小，环身有断续刻痕；环心不填充，保持通透。整体旧金与冷玉双色。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: two slender rings interlocked vertically into one object, the upper ring slightly smaller, broken notch marks along the metal, ring interiors kept empty and see-through. Two-tone material: aged brass and pale jade. Chinese xianxia mystic-grade paired rings. One-pixel ink outline #141A19, five flat tones (brass dark, brass #BDA77B, jade shadow, jade #9FBCB1, one white glint pixel). Centered, 78% canvas, no glow.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 两环相扣关系明确，不得画成同心圆
- 环心镂空，alpha = 0
- 刻痕为单像素缺口，3 到 5 处

#### 14. `accessory_6.png`  · 仙品 r6

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/accessory_6.png` |
| 引擎路径 | `res://content/assets/icons/items/accessory_6.png` |
| 覆盖法宝 | 轮回印（共 1 件） |
| 建议用色 | `#141A19`、`#9FBCB1`、`#BDA77B`、`#B66C61`、`#F2F0E8` |

**画什么**：一方方形玉印，正视略俯，印钮为简化的兽形块面，印面朝前，刻一条首尾相接的回环线（单像素线），寓意轮回。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: a square jade seal seen slightly from above, the knob carved as a simplified beast silhouette built from flat blocks, the front face showing a single continuous loop line that returns to its own start, drawn as one-pixel line. Chinese xianxia immortal-grade seal. One-pixel ink outline #141A19, six flat tones (jade deep, jade mid #9FBCB1, jade light, brass edge #BDA77B, cinnabar #B66C61 on the loop only, cold white #F2F0E8 glint). Centered, 78% canvas, no text, no seal-script characters.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 回环线必须是闭合单线，不得断开
- 印面不得出现任何汉字或篆书笔画
- 朱砂只用于回环线

### 秘宝（4 张，覆盖 24 件法宝）

#### 15. `artifact_3.png`  · 灵品 r3

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/artifact_3.png` |
| 引擎路径 | `res://content/assets/icons/items/artifact_3.png` |
| 覆盖法宝 | 魔道古卷、随缘法器、剑崖拓本（共 3 件） |
| 建议用色 | `#141A19`、`#8A7550`、`#EEE5D1` |

**画什么**：一卷半展开的竹简，左侧卷起、右侧展开三片简，竹片边缘有焦黑痕迹，简面无字（只用两道横向刻线示意）。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: a partially unrolled bamboo slip scroll, left side still rolled, right side showing three flat slips, charred blackened edges, blank slip faces indicated by two horizontal engraving lines only. Chinese xianxia forbidden-scroll artifact. One-pixel ink outline #141A19, four flat tones (bamboo dark, bamboo mid, charred ink, pale paper). Centered, 78% canvas, no characters, no writing.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 不得出现任何文字或伪文字笔画
- 焦黑边缘为不规则缺角，至少 2 处
- 色数 <= 12

#### 16. `artifact_4.png`  · 真品 r4

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/artifact_4.png` |
| 引擎路径 | `res://content/assets/icons/items/artifact_4.png` |
| 覆盖法宝 | 青云剑匣、万卷封魔残页、星轨法印盘、锁脉玄铁环（共 16 件） |
| 建议用色 | `#141A19`、`#8A7550`、`#BDA77B`、`#9FBCB1`、`#F2F0E8` |

**画什么**：一只狭长的漆木剑匣，正面朝前竖立，匣盖微开一道缝，缝中透出一线竖直剑光（单像素亮线，不得成光晕）。匣身上三分处有一枚方形玉嵌件，两端旧金包角。这是 55 件法宝里 16 件共用的一张，必须最精致。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: one narrow tall lacquered wooden sword case standing upright facing the viewer, lid slightly ajar with a single vertical one-pixel line of cold light escaping the seam (no halo, no rays), one square jade inset at the upper third, aged brass corner caps at both ends. This icon covers 16 different treasures, so it must be the most carefully built of the set. Chinese xianxia treasured sword case. One-pixel ink outline #141A19, six flat tones (lacquer dark, lacquer mid, brass #BDA77B, jade #9FBCB1, cold white #F2F0E8 seam light, paper highlight). Centered, 78% canvas, no sword protruding, no open lid.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 匣盖开缝不超过 2 逻辑像素
- 透出光为单像素竖线，长度不超过匣高 1/3
- 玉嵌件为方块，不得画成圆形
- 缩到 26px 必须能看出是长条箱体而非短剑

#### 17. `artifact_5.png`  · 玄品 r5

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/artifact_5.png` |
| 引擎路径 | `res://content/assets/icons/items/artifact_5.png` |
| 覆盖法宝 | 神农鼎、涅槃羽、轮回镜（共 3 件） |
| 建议用色 | `#141A19`、`#8A7550`、`#BDA77B`、`#9FBCB1` |

**画什么**：一只三足圆鼎，双耳外撇，鼎口上方一缕极简青烟（两三个离散像素点，向上偏移，不得连成曲线）。鼎腹有一道环形纹带。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: a round three-legged Chinese bronze cauldron with two outward-flaring handles, one horizontal banded pattern around the belly, and two or three isolated single pixels of pale smoke rising above the mouth (not a continuous wisp, no gradient). Chinese xianxia mystic-grade cauldron. One-pixel ink outline #141A19, five flat tones (bronze dark, bronze mid #8A7550, brass #BDA77B, patina jade #9FBCB1, pale smoke). Centered, 78% canvas, no fire, no glow.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 三足清晰分离，不得粘连成块
- 青烟为 2 到 3 个离散像素
- 鼎耳外撇角度可辨

#### 18. `artifact_6.png`  · 仙品 r6

| 项 | 内容 |
|---|---|
| 落盘绝对路径 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot/content/assets/icons/items/artifact_6.png` |
| 引擎路径 | `res://content/assets/icons/items/artifact_6.png` |
| 覆盖法宝 | 混沌茧、混元神石（共 2 件） |
| 建议用色 | `#141A19`、`#C9C3B4`、`#F2F0E8`、`#BDA77B` |

**画什么**：一块不规则的原石或茧状体，外有数道裂纹，裂纹内部透出极淡的冷白光（用一两个亮色块，不得做成辉光）。外形不对称，重心稳定。

正向 prompt（复制即用）：

```
Single isolated pixel-art game icon on a fully transparent 512x512 canvas, 64x64 logical grid, hard 8px blocks, no anti-aliasing. Subject: one irregular rough stone or cocoon-shaped mass with four or five angular cracks across its surface; inside the widest crack a small cold-white bright block suggests inner light, but no glow, no rays, no bloom. Asymmetric silhouette, visually stable. Chinese xianxia primordial-grade relic. One-pixel ink outline #141A19, six flat tones (stone dark, stone mid, stone lit, crack shadow, cold white #F2F0E8, faint brass #BDA77B fleck). Centered, 78% canvas.
```

负向 prompt：

```
photorealistic, 3D render, CGI, smooth airbrush, soft gradient, blurred edge, anti-aliasing, glow, bloom, lens flare, rim light, drop shadow, cast shadow, ground shadow, background scenery, frame, border, badge, circular emblem, plaque, card, text, letters, numerals, watermark, signature, logo, human figure, hands, face, anime character, modern object, plastic sheen, oversaturated
```

该张专项验收：

- 轮廓必须不对称
- 内部亮块不超过 4 逻辑像素，且不向外扩散
- 裂纹为折线，至少 3 道
- 色数 <= 16

---

## 七、交付流程

**不要一次画完 18 张。** 先交这 3 张做风格校准：

| 顺序 | 文件 | 为什么是它 |
|---|---|---|
| 1 | `artifact_4.png` | 单张覆盖 16 件法宝，最该画精 |
| 2 | `weapon_4.png` | 覆盖 6 件，兵刃里最常出现 |
| 3 | `armor_2.png` | 18 张里最简的一张，用来确认下限 |

这 3 张确认通过后，再批量出剩余 15 张。

## 八、交付后由工程侧执行（你不用管）

1. 图放进 `items\` 目录后**立刻生效**，不需要改代码、不需要重启编辑器
2. 工程侧跑自动校验：

```bash
cd <repo>/godot && python tools/validate_treasure_icons.py
# 期望 TREASURE_ICONS_PASS files=18/18
```

3. 校验通过后接图鉴与坊市列表，并做 26px 可辨认性截图比对

> **提醒**：不要去 `content/data/shops/treasures.json` 里加 `icon` 字段。
> 那份数据被 `source_manifest.json` 按 sha256 + bytes 硬绑定，
> 改一个字节就会让内容索引整体失败。代码走的是路径约定，不需要数据配合。

## 九、常见错误（会直接被校验脚本打回）

| 症状 | 原因 | 正确做法 |
|---|---|---|
| `not aligned to 8x8 block` | 用了抗锯齿或羽化，或画布不是 8 的倍数 | 关闭抗锯齿，按 64 网格落笔 |
| `semi-transparent pixels` | 用了透明度渐变 | alpha 只允许 0 或 255 |
| `colors=17 > 16` | 高光叠太多层 | 按调色板取色，上限 16 色 |
| `corner xx not transparent` | 铺了底色或画布底 | 背景完全透明 |
| `size=1024x1024` | 输出尺寸错 | 统一 512×512 |
| 26px 下一团黑 | 细节过密 | 主体占 78%，减少内部纹理 |

---

**文档来源**：由 `tools/render_painter_handoff.py` 从 `manifest.json` 渲染，
共 18 项。修改 prompt 请改 manifest 后重新渲染，不要直接改本文件。
