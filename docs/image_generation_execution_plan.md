# 《一念仙途》美术资产生成执行计划

> 面向外部AI图像生成工具（如即梦、可灵、Midjourney、Stable Diffusion等）
> 生成目标：34张缺失图片（3张角色图 + 31张场景图）
> 统一规格：832×1144 像素，PNG格式，8-bit RGB

---

## 一、执行总览

```
总任务量：34张图片
├── 角色概念图：3张（放在 assets/characters/）
├── 营地场景：1张（放在 assets/cards/events/）
└── 章节里程碑：30张（放在 assets/cards/events/）

预计耗时：使用AI工具约2-4小时（含迭代调整）
执行顺序：先角色 → 再营地 → 最后章节里程碑（按境界分组）
```

---

## 二、画风统一规范（必须严格遵守）

### 2.1 核心画风：PC-98 复古像素 + 中国古风仙侠

这是项目的统一视觉语言，所有图片必须保持一致：

- **主体**：16-bit 复古像素艺术（PC-98 日式美少女游戏风格）
- **场景**：水墨古风 + 像素渲染，低饱和度色调
- **人物**：精致动漫面部，古风服饰，仙侠元素（灵气、符文、法宝）
- **氛围**：神秘、宿命感、略带忧郁的东方美学
- **色阶**：限制调色板（模拟16-bit色深），避免过度鲜艳

### 2.2 技术规格

| 参数 | 要求 | 说明 |
|------|------|------|
| **分辨率** | 832×1144 | 与现有所有资源统一 |
| **比例** | 3:4（竖屏） | 卡牌场景的标准比例 |
| **格式** | PNG | 场景图用PNG；角色概念图可用WebP |
| **色彩深度** | 8-bit RGB | 兼容性和体积平衡 |
| **透明通道** | 不需要 | 全部用实色背景 |
| **文件大小** | 建议 < 500KB | 保证网页加载速度 |

### 2.3 色调递进表（必须遵守）

每个境界有对应的色调，不能错乱：

| 境界 | 主色调 | 辅助色 | 氛围关键词 |
|------|--------|--------|-----------|
| 炼气期 | 青蓝 `#4a9eff` | 白 `#ffffff` | 初醒、期待、灵气初现 |
| 筑基期 | 翠绿 `#2ecc71` | 白玉 `#f5f5f5` | 成长、宗门、红尘历练 |
| 金丹期 | 金橙 `#f39c12` | 暗红 `#c0392b` | 成熟、正魔抉择、诱惑 |
| 元婴期 | 紫红 `#9b59b6` | 银白 `#ecf0f1` | 超脱、因果、宿命降临 |
| 化神期 | 白金 `#f1c40f` | 深蓝 `#2c3e50` | 神游、天道崩塌、悲悯 |
| 渡劫期 | 暗红 `#e74c3c` | 雷金 `#f1c40f` | 雷劫、心魔、终极对决 |

> **关键**：同一境界的5张里程碑图必须保持色调一致，形成视觉连贯性。

### 2.4 提示词通用后缀（每次生成必须添加）

**中文提示词通用后缀：**
```
，中国古风仙侠风格，16-bit PC-98复古像素风格，像素艺术，低饱和度，832x1144像素，竖屏构图，3:4比例
```

**英文提示词通用后缀（Midjourney）：**
```
, Chinese xianxia fantasy style, 16-bit PC-98 retro pixel art style, pixel art, low saturation, muted colors, 832x1144, --ar 3:4 --niji 6
```

**英文提示词通用后缀（Stable Diffusion）：**
```
, chinese xianxia fantasy, pc-98 pixel art style, 16-bit, pixelart, muted colors, masterpiece, best quality, 832x1144
Negative prompt: 3d render, realistic, photorealistic, western style, modern clothes, lowres, blurry, text, watermark, signature
```

---

## 三、分批执行计划

### 第一批：角色概念图（3张）

**建议工具**：Midjourney v6 或 即梦（Dreamina）
**原因**：角色需要精细面部和服饰，AI对人物生成效果最好

#### 3.1 concept_bai_luoxuan.webp

| 项目 | 内容 |
|------|------|
| **保存路径** | `assets/characters/concept_bai_luoxuan.webp` |
| **角色** | 白落霜（白狐部狐族少女） |
| **核心特征** | 银白色长发、白色狐耳、琥珀色眼眸、素白长裙、气质温柔 |
| **背景** | 南疆竹林或月光下的洞府门口 |
| **姿势** | 正面半身像，站立施礼或托腮凝望 |
| **氛围** | 温柔、报恩、略带忧伤的神秘感 |

**中文提示词：**
```
一位银发狐族少女，白色狐耳，琥珀色眼眸，身穿素白长裙，银发如瀑布般垂落至腰，气质温柔而神秘。背景是月光下的竹林，竹影斑驳。正面半身像，略带忧伤的眼神。中国古风仙侠风格，16-bit PC-98复古像素风格，像素艺术，低饱和度，精致动漫人物立绘，832x1144像素，竖屏构图，3:4比例
```

**英文提示词（Midjourney）：**
```
A silver-haired fox girl with white fox ears and amber eyes, wearing a plain white long dress, silver hair cascading to waist, gentle and mysterious temperament. Background is a bamboo forest under moonlight with dappled shadows. Front-facing half-body portrait, slightly melancholic gaze. Chinese xianxia fantasy style, 16-bit PC-98 retro pixel art style, pixel art, low saturation, exquisite anime character art, 832x1144 --ar 3:4 --niji 6
```

**生成后检查清单：**
- [ ] 银发 + 狐耳 + 琥珀色眼睛 都可见
- [ ] 素白长裙（非现代服装）
- [ ] 背景是竹林/月光（非城市/现代）
- [ ] 像素艺术风格（非写实3D）
- [ ] 尺寸正确 832×1144
- [ ] 保存为 WebP 格式

---

#### 3.2 bai_luoxuan_seductive_v8_greeksculpt.png

| 项目 | 内容 |
|------|------|
| **保存路径** | `assets/characters/bai_luoxuan_seductive_v8_greeksculpt.png` |
| **角色** | 白落霜（90好感度诱惑立绘） |
| **核心特征** | 银发、狐尾、雪夜松林、回眸浅笑、半掩身姿 |
| **服饰** | 低腰白色丝绸旗袍，高开叉，轻纱缠腰半掩 |
| **场景** | 雪夜松林，月光透过树梢，积雪覆盖地面 |
| **氛围** | 魅惑而优雅，狐族的妖媚与人性的温柔并存 |
| **注意** | 此图为 adultContent=true，但保持艺术性和美感，不过度暴露 |

**中文提示词：**
```
银发狐族少女，雪夜松林场景，侧身回眸浅笑，低腰白色丝绸旗袍高开叉设计，轻纱缠绕腰肩半掩，一条白色狐尾从尾椎自然延出。背景是飘雪的松树林，月光透过树梢洒下积雪。氛围魅惑而优雅，狐族妖媚与温柔并存。中国古风仙侠风格，16-bit PC-98复古像素风格，像素艺术，低饱和度冷色调，832x1144像素，竖屏构图，3:4比例
```

**英文提示词（Midjourney）：**
```
Silver-haired fox girl in a snowy pine forest at night, side profile looking back with a faint smile, low-waist white silk qipao with high side slit, sheer gauze draped over shoulders and waist, one white fox tail extending naturally. Snow falling through moonlit pine trees, snow-covered ground. Seductive yet elegant atmosphere, fox spirit allure mixed with human gentleness. Chinese xianxia fantasy, 16-bit PC-98 retro pixel art, pixel art, low saturation cool color palette, 832x1144 --ar 3:4 --niji 6
```

**生成后检查清单：**
- [ ] 银发 + 狐尾 都可见
- [ ] 白色旗袍 + 轻纱（古风服饰）
- [ ] 雪夜松林背景（非城市/室内）
- [ ] 像素艺术风格
- [ ] 尺寸正确 832×1144
- [ ] 保存为 PNG 格式

---

#### 3.3 jiuwei_suyue_seductive.webp

| 项目 | 内容 |
|------|------|
| **保存路径** | `assets/characters/jiuwei_suyue_seductive.webp` |
| **角色** | 九尾溯月（80好感度诱惑立绘） |
| **核心特征** | 九尾天狐、九条雪白狐尾如孔雀开屏、银白色长发、金色妖异眼眸 |
| **场景** | 满月下的月湖，水面倒映银光 |
| **氛围** | 绝艳而神圣，三千年妖皇的威严与孤寂 |
| **注意** | adultContent=true，以月光和狐尾为衣，保持艺术美感 |

**中文提示词：**
```
九尾天狐化身的绝世美人，九条雪白狐尾如孔雀开屏般展开，银白色长发，金色妖异眼眸，月光为衣，九尾半掩娇躯。背景是满月下的月湖，水面倒映银光，夜空繁星。氛围绝艳而神圣，三千年妖皇的威严与孤寂。中国古风仙侠风格，16-bit PC-98复古像素风格，像素艺术，蓝白色调，832x1144像素，竖屏构图，3:4比例
```

**英文提示词（Midjourney）：**
```
Nine-tailed celestial fox transformed into a stunning beauty, nine snowy white tails fanned out like a peacock, silver-white long hair, golden alluring eyes, clothed in moonlight with tails partially covering body. Background is a moonlit lake reflecting silver light, starry night sky. Ethereal and divine atmosphere, three-thousand-year fox queen's majesty and loneliness. Chinese xianxia fantasy, 16-bit PC-98 retro pixel art, pixel art, blue-white color scheme, 832x1144 --ar 3:4 --niji 6
```

**生成后检查清单：**
- [ ] 九条狐尾（清晰可见）
- [ ] 银发 + 金眼
- [ ] 月湖 + 满月背景
- [ ] 像素艺术风格
- [ ] 尺寸正确 832×1144
- [ ] 保存为 WebP 格式

---

### 第二批：营地场景（1张）

**建议工具**：Stable Diffusion XL + PC-98 LoRA（或即梦选"像素"风格）
**原因**：场景需要稳定的大构图，AI对场景生成一致性较好

#### 4.1 scene_camp.png

| 项目 | 内容 |
|------|------|
| **保存路径** | `assets/cards/events/scene_camp.png` |
| **场景** | 洞府遗迹（营地休息点） |
| **描述** | 崇山峻岭间的隐秘废弃洞府，山壁上有被藤蔓半掩的石门洞口，洞内透出微弱灵气光芒。周围古木参天，云雾缭绕，溪流从石缝间流过 |
| **色调** | 青绿 + 深绿（参考炼气期色调） |
| **氛围** | 宁静、神秘、安全、灵气浓郁 |

**中文提示词：**
```
崇山峻岭间的隐秘废弃洞府，山壁上有一个被藤蔓半掩的石门洞口，洞内透出微弱的青色灵气光芒。周围古木参天，云雾缭绕，溪流从石缝间流过，苔藓覆盖岩石。氛围宁静而神秘，灵气浓郁。中国古风仙侠场景，16-bit PC-98复古像素风格，像素艺术，青绿色调，低饱和度，832x1144像素，竖屏构图，3:4比例
```

**英文提示词（Midjourney）：**
```
A hidden abandoned cave dwelling among towering mountains, a stone door entrance half-covered by vines on a cliff face, faint cyan spiritual light glowing from within. Ancient trees reaching skyward, mist and clouds swirling, a stream flowing through stone crevices, moss-covered rocks. Serene and mysterious atmosphere, rich spiritual energy. Chinese xianxia fantasy scene, 16-bit PC-98 retro pixel art style, pixel art, green-blue color palette, low saturation, 832x1144 --ar 3:4 --niji 6
```

**生成后检查清单：**
- [ ] 山壁 + 石门洞口 + 藤蔓
- [ ] 洞内灵气光芒（青色）
- [ ] 古木 + 云雾 + 溪流
- [ ] 像素艺术风格
- [ ] 尺寸正确 832×1144
- [ ] 保存为 PNG 格式

---

### 第三批：章节里程碑场景（30张）

**建议工具**：Stable Diffusion XL + 批量脚本（效率最高）
**替代工具**：即梦/可灵AI 逐张生成（适合少量精细化）

**执行策略**：按境界分6组，每组5张。同组内保持色调一致。

> **重要**：每张图必须在右下角或顶部保留文字标识区域（纯色块），因为游戏代码可能会在这些位置叠加文字标签。建议生成时在画面中央偏上放置主体，底部留 150px 的空白区域给UI文字。

---

#### 5.1 第一章：凡尘初醒（炼气期 qi）—— 5张

**主色调**：青蓝 `#4a9eff` + 白 `#ffffff`

| 文件名 | 标题 | 进度 | 场景描述 | 核心元素 |
|--------|------|------|---------|---------|
| `scene_ch_qi_20.png` | 灵根觉醒 | 20% | 丹田深处经脉颤动，一缕灵气在体内流转 | 少年冥想、青色灵气光、废弃道观、半卷古籍 |
| `scene_ch_qi_40.png` | 初遇机缘 | 40% | 废弃道观中发现半卷古朴修炼法门 | 破败道观、石台玉简、窗外散修身影、蛛网苔藓 |
| `scene_ch_qi_60.png` | 师承抉择 | 60% | 剑宗长老与丹霞谷丹师同时伸出橄榄枝 | 山门前平台、剑宗长老（背剑）、丹师（药葫芦）、少年犹豫 |
| `scene_ch_qi_80.png` | 入道试炼 | 80% | 深入妖兽出没的迷雾森林，取回百年灵草 | 浓雾森林、扭曲巨木、发光苔藓、远处妖兽轮廓、少年握剑 |
| `scene_ch_qi_100.png` | 突破筑基 | 100% | 灵气如潮水涌入丹田，气旋初成 | 山洞内、青色灵气漩涡、头顶雷云、丹田光芒、宏大氛围 |

**中文提示词模板（以 `scene_ch_qi_20.png` 为例）：**
```
一位少年盘膝而坐，闭目冥想，丹田处发出微弱的青色灵气光芒。周围是简陋的废弃道观，半卷古籍摊开在膝前，尘埃在光线中浮动。氛围神秘而充满期待。中国古风仙侠场景，16-bit PC-98复古像素风格，像素艺术，青蓝色调，低饱和度，832x1144像素，竖屏构图，3:4比例
```

**英文提示词模板（Midjourney）：**
```
A young cultivator sitting cross-legged in meditation, eyes closed, faint cyan spiritual light glowing from the dantian. Surroundings are a dilapidated abandoned Taoist temple, half a worn ancient manual open on the lap, dust particles floating in the light. Mysterious and hopeful atmosphere. Chinese xianxia fantasy scene, 16-bit PC-98 retro pixel art, pixel art, cyan-blue tones, low saturation, 832x1144 --ar 3:4 --niji 6
```

---

#### 5.2 第二章：宗门风云（筑基期 foundation）—— 5张

**主色调**：翠绿 `#2ecc71` + 白玉 `#f5f5f5`

| 文件名 | 标题 | 进度 | 场景描述 | 核心元素 |
|--------|------|------|---------|---------|
| `scene_ch_foundation_20.png` | 拜入宗门 | 20% | 青云缭绕的三宗四派山门，长老目光审视 | 宏伟仙宗山门、青云缭绕、白玉台阶、石剑雕塑、长老审视 |
| `scene_ch_foundation_40.png` | 师门历练 | 40% | 偏远山村的异象调查，黑影山间游荡 | 黄昏山村、炊烟、恐惧村民、远处黑影、少年背行囊 |
| `scene_ch_foundation_60.png` | 门派纷争 | 60% | 内门与外门弟子因灵矿开采权爆发冲突 | 宗门广场、两群对峙弟子、灵矿坑洞、五彩灵光、旗帜 |
| `scene_ch_foundation_80.png` | 红尘试炼 | 80% | 凡间街市，算命先生拦住少年预言大劫 | 热闹街市、摊贩、白须算命先生、卦旗、乌云远景 |
| `scene_ch_foundation_100.png` | 突破金丹 | 100% | 液态真元旋转凝固，长老齐聚护法 | 闭关密室、灵火蜡烛、金色真元漩涡、护法阵法、神圣惊险 |

---

#### 5.3 第三章：丹心问道（金丹期 golden）—— 5张

**主色调**：金橙 `#f39c12` + 暗红 `#c0392b`

| 文件名 | 标题 | 进度 | 场景描述 | 核心元素 |
|--------|------|------|---------|---------|
| `scene_ch_golden_20.png` | 金丹初成 | 20% | 金色圆丹缓缓旋转，魔道开始注意 | 静室内视、金色圆丹、窗外黑影、成就与危机并存 |
| `scene_ch_golden_40.png` | 秘境探索 | 40% | 太虚秘境传送阵，时间流速不同 | 古老传送阵、蓝色光芒、扭曲时空、上古凶兽轮廓 |
| `scene_ch_golden_60.png` | 正魔抉择 | 60% | 黑衣女子拦住去路，邀请入魔道 | 荒山野道、黑衣女子、窒息威压、诱惑笑意、少年凝重 |
| `scene_ch_golden_80.png` | 道侣机缘 | 80% | 灵泉瀑布旁，修行身影转头对视 | 灵泉瀑布、银练水流、彩虹水雾、石台修行身影、暧昧情愫 |
| `scene_ch_golden_100.png` | 突破元婴 | 100% | 金丹碎裂，元婴将出，九死一生 | 内视丹碎、裂纹白光、婴儿光影、少年面容扭曲、剧痛 |

---

#### 5.4 第四章：碎丹成婴（元婴期 nascent）—— 5张

**主色调**：紫红 `#9b59b6` + 银白 `#ecf0f1`

| 文件名 | 标题 | 进度 | 场景描述 | 核心元素 |
|--------|------|------|---------|---------|
| `scene_ch_nascent_20.png` | 元婴化形 | 20% | 元婴盘膝而坐，面目与修行者相同 | 内视元婴、寸许婴儿、银白光芒、双眼睁开、世界清晰 |
| `scene_ch_nascent_40.png` | 天劫预兆 | 40% | 深夜打坐时，天空雷光乍现劈落面前 | 深夜山顶、巨石打坐、紫色雷电、天裂、雷龙游走 |
| `scene_ch_nascent_60.png` | 因果清算 | 60% | 因果轮盘转动，善恶因同时发芽 | 巨大轮盘虚影、黑白两半、丝线延伸、金银黑气、宿命 |
| `scene_ch_nascent_80.png` | 宿命抉择 | 80% | 混沌漏洞体质，要么成仙要么成魔 | 观星台、铜镜、灵根影像、混沌之力、长老警告 |
| `scene_ch_nascent_100.png` | 突破化神 | 100% | 元婴成长为元神，以精血为引 | 闭关密室、割破手指、血滴丹田、元婴沐浴精血、金光元神 |

---

#### 5.5 第五章：神游太虚（化神期 deity）—— 5张

**主色调**：白金 `#f1c40f` + 深蓝 `#2c3e50`

| 文件名 | 标题 | 进度 | 场景描述 | 核心元素 |
|--------|------|------|---------|---------|
| `scene_ch_deity_20.png` | 化神之变 | 20% | 感知超越肉身，看到因果丝线灵气潮流 | 悬浮半空、白金双眼、丝线连接万物、灵气如潮、善恶灯火 |
| `scene_ch_deity_40.png` | 上古秘辛 | 40% | 荒废遗迹中发现石碑记载混沌体质 | 荒废遗迹、断壁残垣、发光藤蔓、半块石碑、古老金光碑文 |
| `scene_ch_deity_60.png` | 世界崩塌 | 60% | 天边出现空间裂缝，天道正在崩塌 | 天际裂缝、虚无黑暗、大地震动、山川崩塌、凡人奔逃、高空俯瞰 |
| `scene_ch_deity_80.png` | 众生因果 | 80% | 看到每个人的因果线，与自己相连 | 云端俯瞰、丝线汇聚、金银黑灰因果、宏大悲悯 |
| `scene_ch_deity_100.png` | 突破渡劫 | 100% | 化神大圆满，天空乌云密布雷龙游走 | 万丈悬崖、乌云密布、紫金雷龙、灵气汇聚、宏大肃杀 |

---

#### 5.6 第六章：天劫飞升（渡劫期 tribulation）—— 5张

**主色调**：暗红 `#e74c3c` + 雷金 `#f1c40f`

| 文件名 | 标题 | 进度 | 场景描述 | 核心元素 |
|--------|------|------|---------|---------|
| `scene_ch_tribulation_20.png` | 天劫降临 | 20% | 第一道劫雷劈落，紫金雷电直贯天灵 | 渡劫台、盘坐、紫金雷电、天灵盖、电光照亮天空、衣袍猎猎 |
| `scene_ch_tribulation_40.png` | 九九雷劫 | 40% | 第四十道劫雷已过，劫雷蕴含造化 | 焦黑身影、眼神清明、雷云下、白金色劫雷、灵气漩涡 |
| `scene_ch_tribulation_60.png` | 心魔大劫 | 60% | 第六十道劫雷劈在心上，心魔显形 | 内心世界、镜像身影、愤恨眼神、记忆碎片漂浮、诡异内省 |
| `scene_ch_tribulation_80.png` | 最后抉择 | 80% | 第八十道劫雷后看到仙界入口和凡间少年 | 天地寂静、天光裂缝、仙界入口、过去自己重叠、宿命抉择 |
| `scene_ch_tribulation_100.png` | 飞升陨落 | 100% | 最后一道九九归一雷，决定一切 | 终极雷光、九九归一、因果面孔、纯白+彩虹边缘、宏大终极 |

---

## 四、批量生成工作流（推荐）

### 4.1 使用即梦（Dreamina）批量生成

**步骤：**

1. 打开 [即梦官网](https://jimeng.jianying.com)
2. 选择 **"图片生成"** → **"动漫"** 风格
3. 选择比例 **3:4**（竖屏）
4. 复制本文档中的中文提示词，逐张粘贴生成
5. 生成后点击 **"下载原图"**
6. 用图片编辑工具（如 Photopea/Photoshop）裁剪到 **832×1144**
7. 保存为 PNG，命名正确后放到对应目录

**优点**：中文提示词理解最好，古风场景生成质量高
**缺点**：需要逐张操作，30张约需1-2小时

### 4.2 使用可灵AI 批量生成

**步骤：**

1. 打开 [可灵AI](https://klingai.com)
2. 选择 **"图片生成"** → **"动漫插画"** 风格
3. 选择比例 **3:4**
4. 复制提示词生成
5. 下载后裁剪到 832×1144

**优点**：国产模型，对仙侠场景理解较好
**缺点**：可能需要多次迭代调整

### 4.3 使用 Midjourney 批量生成（最高质量）

**步骤：**

1. 在 Discord 中进入 Midjourney 频道
2. 使用 `/imagine` 命令，粘贴英文提示词
3. 添加参数 `--ar 3:4 --niji 6 --style raw`
4. 生成后选择 U1/U2/U3/U4 中最满意的一张
5. 使用 `/show` 下载原图，裁剪到 832×1144

**优点**：人物和场景质量最高，风格一致性强
**缺点**：需要订阅，费用较高

**批量技巧**：使用 MJ 的 "Variation" 功能，先生成一张满意的基准图，然后对每个里程碑做 Variation 保持风格一致。

### 4.4 使用 Stable Diffusion XL 本地批量（最效率）

如果你有本地显卡，这是效率最高的方案：

**步骤：**

1. 安装 **Stable Diffusion WebUI**（AUTOMATIC1111）
2. 下载 **PC-98/像素风 LoRA** 模型（Civitai 搜索 "pixel art" "PC-98"）
3. 配置参数：
   - Checkpoint：任意动漫大模型（如 Counterfeit、AbyssOrangeMix）
   - LoRA：`<lora:pc98_pixel:0.8>`
   - 分辨率：832×1144
   - Steps：30
   - CFG：7
   - Sampler：DPM++ 2M Karras
4. 使用 **Prompts from file or textbox** 脚本批量生成

**参考提示词文件格式（每行一个）：**
```
A young cultivator sitting cross-legged in meditation, faint cyan spiritual light glowing from the dantian, chinese xianxia fantasy, pc-98 pixel art style, 16-bit, pixelart, muted colors, masterpiece, best quality, 832x1144
Negative prompt: 3d render, realistic, photorealistic, western style, modern clothes, lowres, blurry, text, watermark, signature
```

**优点**：批量自动化，一次生成全部30张，风格完全一致
**缺点**：需要8GB+显存，配置较复杂

---

## 五、质量检查清单（每张图必须过检）

生成每张图后，对照以下清单检查：

### 5.1 技术检查
- [ ] 尺寸 = 832×1144 像素（严格）
- [ ] 格式正确（PNG 或 WebP）
- [ ] 文件大小 < 1MB（建议 < 500KB）
- [ ] 无文字水印、无签名、无AI生成标识
- [ ] 色彩为 8-bit RGB（非 16-bit 或 32-bit）

### 5.2 画风检查
- [ ] 是像素艺术风格（有明显的像素颗粒感）
- [ ] 不是写实3D渲染（不是照片级真实感）
- [ ] 不是现代动漫风格（有复古感）
- [ ] 色调符合境界色表（不偏离）
- [ ] 中国古风元素（非西方奇幻）

### 5.3 内容检查
- [ ] 场景图：画面主体在上方2/3，底部留150px空白给UI文字
- [ ] 角色图：人物面部清晰可辨，服饰古风
- [ ] 场景元素符合提示词描述（没有遗漏关键元素）
- [ ] 背景氛围正确（不是错误场景）

### 5.4 命名检查
- [ ] 文件名与本文档完全一致（大小写敏感）
- [ ] 角色图放在 `assets/characters/`
- [ ] 场景图放在 `assets/cards/events/`

---

## 六、文件目录结构（最终放置位置）

生成完成后，文件应按以下结构放置：

```
assets/
├── characters/
│   ├── concept_bai_luoxuan.webp            ← 新图
│   ├── bai_luoxuan_seductive_v8_greeksculpt.png  ← 新图
│   ├── jiuwei_suyue_seductive.webp         ← 新图
│   └── ... (现有文件不变)
├── cards/
│   ├── events/
│   │   ├── scene_camp.png                  ← 新图
│   │   ├── scene_ch_qi_20.png              ← 新图
│   │   ├── scene_ch_qi_40.png              ← 新图
│   │   ├── scene_ch_qi_60.png              ← 新图
│   │   ├── scene_ch_qi_80.png              ← 新图
│   │   ├── scene_ch_qi_100.png             ← 新图
│   │   ├── scene_ch_foundation_20.png      ← 新图
│   │   ├── scene_ch_foundation_40.png      ← 新图
│   │   ├── scene_ch_foundation_60.png      ← 新图
│   │   ├── scene_ch_foundation_80.png      ← 新图
│   │   ├── scene_ch_foundation_100.png     ← 新图
│   │   ├── scene_ch_golden_20.png          ← 新图
│   │   ├── scene_ch_golden_40.png          ← 新图
│   │   ├── scene_ch_golden_60.png          ← 新图
│   │   ├── scene_ch_golden_80.png          ← 新图
│   │   ├── scene_ch_golden_100.png         ← 新图
│   │   ├── scene_ch_nascent_20.png         ← 新图
│   │   ├── scene_ch_nascent_40.png         ← 新图
│   │   ├── scene_ch_nascent_60.png         ← 新图
│   │   ├── scene_ch_nascent_80.png         ← 新图
│   │   ├── scene_ch_nascent_100.png        ← 新图
│   │   ├── scene_ch_deity_20.png           ← 新图
│   │   ├── scene_ch_deity_40.png           ← 新图
│   │   ├── scene_ch_deity_60.png           ← 新图
│   │   ├── scene_ch_deity_80.png           ← 新图
│   │   ├── scene_ch_deity_100.png          ← 新图
│   │   ├── scene_ch_tribulation_20.png     ← 新图
│   │   ├── scene_ch_tribulation_40.png     ← 新图
│   │   ├── scene_ch_tribulation_60.png     ← 新图
│   │   ├── scene_ch_tribulation_80.png     ← 新图
│   │   └── scene_ch_tribulation_100.png    ← 新图
│   └── ... (现有文件不变)
└── ... (其他目录不变)
```

---

## 七、常见问题 FAQ

**Q1：生成的图不是像素风格怎么办？**
> 在提示词中强调 "16-bit PC-98 retro pixel art style, pixel art"，如果使用 Stable Diffusion，加载 PC-98 或 pixel art 的 LoRA 模型。

**Q2：角色图和场景图风格不一致怎么办？**
> 统一使用同一套提示词后缀，选择同一AI工具（如全部用 Midjourney --niji 6），保持 "Chinese xianxia fantasy" 和 "pixel art" 关键词一致。

**Q3：尺寸不是 832×1144 怎么办？**
> 用 Photopea（免费在线PS）或系统自带的图片编辑器裁剪到 832×1144，使用"中心裁剪"保持主体居中。

**Q4：AI生成的图有文字/水印怎么办？**
> 用 Photopea 的修复画笔工具去除，或在提示词中添加 "no text, no watermark, no signature"。

**Q5：生成的图色调偏离了境界色表怎么办？**
> 在提示词中明确指定色调，如 "cyan-blue tones"（炼气）或 "dark red-gold lightning tones"（渡劫）。生成后可用图片编辑器的色温/色相调整工具微调。

**Q6：30张章节里程碑生成太慢怎么办？**
> 推荐用 Stable Diffusion 的批量生成脚本，一次性生成全部30张。或使用 Midjourney 的 "Vary (Region)" 功能，先做好一张基准图，然后对其他图做局部变化保持风格一致。

---

*本计划由代码自动化扫描 + 人工整理生成，覆盖全部34个缺失文件。*
*执行完成后，建议运行游戏验证所有图片正常加载。*
