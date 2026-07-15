# 《一念仙途》缺失美术资源需求清单

> 生成时间：2026-07-14
> 扫描范围：src/*.js, data/**/*.json, index.html
> 现有文件：313个 | 缺失文件：34个
> 目标尺寸：832×1144 像素（PNG，8-bit RGB）— 与现有资源统一

---

## 一、角色概念图（3张）

### 1. concept_bai_luoxuan.webp

| 字段 | 内容 |
|------|------|
| **文件名** | `assets/characters/concept_bai_luoxuan.webp` |
| **用途** | 道侣「白落霜」基础概念立绘，6个好感度阶段共用（幼狐→初见→参汤→月下→婚契） |
| **引用位置** | `data/companions/portrait_stages.json` 第 13、23、33、43、53 行 |
| **角色设定** | 白狐部族人，白衣银发，琥珀色眼眸，温柔报恩型角色 |
| **画风参考** | 现有 `concept_jiuwei_suyue.webp`（九尾溯月概念图，AI生成动漫/写实风） |
| **建议尺寸** | 512×768 像素（与现有 concept 图一致） |
| **格式** | WebP |

**中文 AI 绘画提示词：**
```
一位银发狐族少女，白色狐耳，琥珀色眼眸，身穿素白长裙，银发如瀑布般垂落，气质温柔而神秘。背景为南疆竹林或月光下的洞府。中国古风仙侠风格，精致动漫人物立绘，柔和光线，细腻面部特征，正面半身像。
```

**英文 AI 绘画提示词（Midjourney/Stable Diffusion）：**
```
A silver-haired fox girl with white fox ears and amber eyes, wearing a plain white long dress, silver hair cascading like a waterfall, gentle and mysterious temperament. Background is a bamboo forest in southern border or a cave dwelling under moonlight. Chinese ancient fantasy xianxia style, exquisite anime character portrait, soft lighting, delicate facial features, front-facing half-body shot, high detail, 8k --ar 2:3 --niji 6
```

---

### 2. bai_luoxuan_seductive_v8_greeksculpt.png

| 字段 | 内容 |
|------|------|
| **文件名** | `assets/characters/bai_luoxuan_seductive_v8_greeksculpt.png` |
| **用途** | 道侣「白落霜」90好感度诱惑立绘（adultContent: true） |
| **引用位置** | `data/companions/portrait_stages.json` 第 63 行 |
| **角色设定** | 白狐化形，雪夜松林，回眸浅笑，半掩狐媚 |
| **画风参考** | 现有 `jian_linger_seductive.webp`、`jiuwei_suyue_sheer_pc98_v*.png` |
| **建议尺寸** | 832×1144 像素 |
| **格式** | PNG |

**中文 AI 绘画提示词：**
```
银发狐族少女，雪夜松林场景，侧身回眸浅笑，低腰白色丝绸旗袍，高开叉设计，轻纱缠绕腰肩半掩，白色狐尾从尾椎自然延出。背景是飘雪的松树林，月光透过树梢洒下。氛围魅惑而优雅，中国古风仙侠，16-bit PC-98复古像素风格，像素艺术，低饱和度冷色调。
```

**英文 AI 绘画提示词：**
```
Silver-haired fox girl in a snowy pine forest at night, side profile looking back with a faint smile, low-waist white silk qipao with high side slit, sheer gauze draped over shoulders and waist, white fox tail extending naturally. Snow falling through moonlit pine trees. Seductive yet elegant atmosphere. Chinese xianxia fantasy, 16-bit PC-98 retro pixel art style, pixel art, low saturation cool color palette, 832x1144 --ar 3:4
```

---

### 3. jiuwei_suyue_seductive.webp

| 字段 | 内容 |
|------|------|
| **文件名** | `assets/characters/jiuwei_suyue_seductive.webp` |
| **用途** | 道侣「九尾溯月」80好感度诱惑立绘（adultContent: true） |
| **引用位置** | `data/companions/portrait_stages.json` 第 234 行 |
| **角色设定** | 九尾天狐，九尾如孔雀开屏展开，月光为衣 |
| **画风参考** | 现有 `jiuwei_suyue_sheer_pc98_v8_final.png`、`jiuwei_suyue_water.png` |
| **建议尺寸** | 832×1144 像素 |
| **格式** | WebP |

**中文 AI 绘画提示词：**
```
九尾天狐化身的绝世美人，九条雪白狐尾如孔雀开屏般展开，银白色长发，金色妖异眼眸，身无寸缕以月光为衣，九尾半掩娇躯。背景是满月下的月湖，水面倒映银光。氛围绝艳而神圣，中国古风仙侠，16-bit PC-98复古像素风格，像素艺术，蓝白色调。
```

**英文 AI 绘画提示词：**
```
Nine-tailed celestial fox transformed into a stunning beauty, nine snowy white tails fanned out like a peacock, silver-white long hair, golden alluring eyes, clothed only in moonlight with tails partially covering body. Background is a moonlit lake reflecting silver light. Ethereal and divine atmosphere. Chinese xianxia fantasy, 16-bit PC-98 retro pixel art style, pixel art, blue-white color scheme, 832x1144 --ar 3:4
```

---

## 二、场景图（31张）

### 2.1 营地场景（1张）

#### scene_camp.png

| 字段 | 内容 |
|------|------|
| **文件名** | `assets/cards/events/scene_camp.png` |
| **用途** | 营地卡牌「洞府遗迹」场景图 |
| **引用位置** | `data/cards/camp.json` 第 8 行 |
| **场景描述** | 崇山峻岭间的隐秘废弃洞府，灵气浓郁，安全静谧 |
| **画风参考** | 现有 `scene_qi_q_cave.png`、`scene_fd_f_shop.png` |
| **建议尺寸** | 832×1144 像素 |
| **格式** | PNG |

**中文 AI 绘画提示词：**
```
崇山峻岭间的隐秘废弃洞府，山壁上有一个被藤蔓半掩的石门洞口，洞内透出微弱的灵气光芒。周围古木参天，云雾缭绕，溪流从石缝间流过。氛围宁静而神秘，中国古风仙侠场景，16-bit PC-98复古像素风格，像素艺术，青绿色调，低饱和度。
```

**英文 AI 绘画提示词：**
```
A hidden abandoned cave dwelling among towering mountains, a stone door entrance half-covered by vines on a cliff face, faint spiritual light glowing from within. Ancient trees reaching skyward, mist and clouds swirling, a stream flowing through stone crevices. Serene and mysterious atmosphere. Chinese xianxia fantasy scene, 16-bit PC-98 retro pixel art style, pixel art, green-blue color palette, low saturation, 832x1144 --ar 3:4
```

---

### 2.2 章节里程碑场景图（30张）

**统一规格：**
- 尺寸：832×1144 像素
- 格式：PNG，8-bit RGB
- 画风：16-bit PC-98 复古像素风格 / 水墨古风场景
- 色调：随境界递进逐渐变化（炼气=青蓝 → 筑基=翠绿 → 金丹=金橙 → 元婴=紫红 → 化神=白金 → 渡劫=暗红+雷电）

---

#### 第一章：凡尘初醒（炼气期 qi）

| 文件名 | 标题 | 阈值 | 场景描述 | 中文提示词 | 英文提示词 |
|--------|------|------|---------|-----------|-----------|
| `scene_ch_qi_20.png` | 灵根觉醒 | 20 | 丹田深处经脉颤动，一缕灵气在体内流转 | 一位少年盘膝而坐，闭目冥想，丹田处发出微弱的青色灵气光芒。周围是简陋的废弃道观，半卷古籍摊开在膝前。氛围神秘而充满期待。中国古风仙侠，16-bit PC-98像素风格，青蓝色调。 | A young cultivator sitting cross-legged in meditation, eyes closed, a faint cyan spiritual light glowing from the dantian. Surroundings are a dilapidated abandoned Taoist temple, half a worn ancient manual open on the lap. Mysterious and hopeful atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, cyan-blue tones, 832x1144 --ar 3:4 |
| `scene_ch_qi_40.png` | 初遇机缘 | 40 | 废弃道观中发现半卷古朴修炼法门 | 破败的道观内，墙上布满蛛网和苔藓，中央石台上放着一卷散发微光的古朴玉简。窗外有散修身影闪过。氛围神秘而紧张。中国古风仙侠，16-bit PC-98像素风格，暗青色调。 | Inside a ruined Taoist temple, cobwebs and moss covering the walls, an ancient jade scroll emitting faint light on a central stone pedestal. A wandering cultivator's silhouette flashes past the window. Mysterious and tense atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, dark cyan tones, 832x1144 --ar 3:4 |
| `scene_ch_qi_60.png` | 师承抉择 | 60 | 剑宗长老与丹霞谷丹师同时伸出橄榄枝 | 山门前的平台上，左侧站着一位背负长剑、气势凌厉的剑宗长老，右侧是一位手持药葫芦、气质温和的丹师。中间是犹豫的少年。氛围庄重而抉择沉重。中国古风仙侠，16-bit PC-98像素风格，对比色构图。 | On a platform before a mountain gate, a sword sect elder with a long sword on his back stands on the left with fierce aura, while an alchemist holding a medicine gourd stands on the right with gentle temperament. A hesitant youth stands between them. Solemn and weighty atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, contrasting colors, 832x1144 --ar 3:4 |
| `scene_ch_qi_80.png` | 入道试炼 | 80 | 深入妖兽出没的迷雾森林，取回百年灵草 | 浓雾弥漫的古老森林，参天巨木的枝干扭曲如龙，地面覆盖着发光的苔藓和菌类。远处传来妖兽的嘶吼声，少年握紧手中长剑。氛围危险而刺激。中国古风仙侠，16-bit PC-98像素风格，墨绿色调。 | A mist-shrouded ancient forest, towering twisted trees like dragons, the ground covered in glowing moss and fungi. A beast's roar echoes from afar as the young cultivator grips his sword. Dangerous and thrilling atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, dark green tones, 832x1144 --ar 3:4 |
| `scene_ch_qi_100.png` | 突破筑基 | 100 | 灵气如潮水涌入丹田，气旋初成 | 少年盘坐在山洞中，周身被青色灵气漩涡包裹，头顶凝聚着淡淡的雷云。丹田处光芒大盛，气旋初成。氛围宏大而紧张。中国古风仙侠，16-bit PC-98像素风格，青蓝+金色光芒。 | A young cultivator sitting in a cave, surrounded by a swirling cyan spiritual energy vortex, faint thunderclouds gathering above. Brilliant light erupts from the dantian as the qi vortex forms. Grand and tense atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, cyan-blue with golden light, 832x1144 --ar 3:4 |

---

#### 第二章：宗门风云（筑基期 foundation）

| 文件名 | 标题 | 阈值 | 场景描述 | 中文提示词 | 英文提示词 |
|--------|------|------|---------|-----------|-----------|
| `scene_ch_foundation_20.png` | 拜入宗门 | 20 | 青云缭绕的三宗四派山门，长老目光审视 | 宏伟的仙宗山门，青云缭绕，白玉台阶直通云端。山门两侧立着巨大的石剑雕塑。几位长老的目光落在台阶下的少年身上。氛围庄严而充满希望。中国古风仙侠，16-bit PC-98像素风格，翠绿色调+白玉质感。 | A magnificent immortal sect mountain gate, azure clouds swirling around it, white jade stairs reaching toward the heavens. Giant stone sword sculptures flank the gate. Several elders' gazes fall upon the youth at the bottom of the stairs. Solemn and hopeful atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, jade green with white jade textures, 832x1144 --ar 3:4 |
| `scene_ch_foundation_40.png` | 师门历练 | 40 | 偏远山村的异象调查，黑影山间游荡 | 黄昏时分的偏远山村，炊烟袅袅，但村民面露恐惧。远处的山峦间有黑色影子在树梢间穿梭。少年背着行囊站在村口。氛围诡异而紧张。中国古风仙侠，16-bit PC-98像素风格，暗黄+暗绿色调。 | A remote mountain village at dusk, cooking smoke rising, but villagers show fear. Dark shadows flit through the treetops on distant hills. The young cultivator stands at the village entrance with a travel pack. Eerie and tense atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, dark yellow-green tones, 832x1144 --ar 3:4 |
| `scene_ch_foundation_60.png` | 门派纷争 | 60 | 内门与外门弟子因灵矿开采权爆发冲突 | 宗门广场内，两群弟子对峙，中间是被挖开的灵矿坑洞，散发着五彩灵光。旗帜分立两侧，剑拔弩张。氛围紧张而火药味十足。中国古风仙侠，16-bit PC-98像素风格，对比强烈的红蓝色调。 | Inside a sect square, two groups of disciples face off, a dug-out spirit mine pit glowing with multicolored light between them. Banners stand on opposite sides, swords drawn. Tense and explosive atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, strong red-blue contrast, 832x1144 --ar 3:4 |
| `scene_ch_foundation_80.png` | 红尘试炼 | 80 | 凡间街市，算命先生拦住少年预言大劫 | 热闹的古代街市，摊贩叫卖，孩童嬉戏。一位白须算命先生手持卦旗拦住了少年。远处的天空有乌云聚集。氛围市井而暗藏危机。中国古风仙侠，16-bit PC-98像素风格，暖色调+乌云对比。 | A bustling ancient marketplace, vendors calling out, children playing. A white-bearded fortune teller with a divination flag blocks the youth's path. Dark clouds gather in the distant sky. Lively yet ominous atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, warm tones with dark cloud contrast, 832x1144 --ar 3:4 |
| `scene_ch_foundation_100.png` | 突破金丹 | 100 | 液态真元旋转凝固，长老齐聚护法 | 庄严的闭关密室，四周点燃着灵火蜡烛。少年盘坐中央，周身环绕着金色液态真元漩涡。几位长老在周围布下护法阵法。氛围神圣而惊险。中国古风仙侠，16-bit PC-98像素风格，金色+暗红色调。 | A solemn closed-door cultivation chamber, spirit-fire candles burning around the perimeter. The youth sits in the center, surrounded by a golden liquid true essence vortex. Several elders set up protective formations around him. Sacred yet perilous atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, gold with dark red tones, 832x1144 --ar 3:4 |

---

#### 第三章：丹心问道（金丹期 golden）

| 文件名 | 标题 | 阈值 | 场景描述 | 中文提示词 | 英文提示词 |
|--------|------|------|---------|-----------|-----------|
| `scene_ch_golden_20.png` | 金丹初成 | 20 | 金色圆丹缓缓旋转，魔道开始注意 | 丹田内视视角，一颗拳头大小的金色圆丹缓缓旋转，散发着温热金光。背景是少年所在的静室，窗外有黑色身影闪过。氛围成就与危机并存。中国古风仙侠，16-bit PC-98像素风格，金色+暗黑色调。 | Internal dantian view, a fist-sized golden core slowly rotating, emitting warm golden light. The youth's meditation room in the background, a dark silhouette flashing past the window. Atmosphere of achievement mixed with crisis. Chinese xianxia, 16-bit PC-98 pixel art, gold with dark tones, 832x1144 --ar 3:4 |
| `scene_ch_golden_40.png` | 秘境探索 | 40 | 太虚秘境传送阵，时间流速不同 | 古老的传送阵散发着蓝色光芒，阵纹在地面上流转。传送门内是扭曲的时空景象——外界一日，阵内百日。远处有上古凶兽的轮廓。氛围神秘而危险。中国古风仙侠，16-bit PC-98像素风格，蓝紫色调。 | An ancient teleportation array emitting blue light, array patterns flowing across the ground. The portal shows distorted space-time within—one day outside equals a hundred days inside. The silhouette of an ancient beast looms in the distance. Mysterious and dangerous atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, blue-purple tones, 832x1144 --ar 3:4 |
| `scene_ch_golden_60.png` | 正魔抉择 | 60 | 黑衣女子拦住去路，邀请入魔道 | 荒山野道，一位黑衣女子拦路而立，周身散发着令人窒息的威压。她的眼眸深邃如渊，嘴角带着一丝诱惑的笑意。少年站在对面，面色凝重。氛围紧张而诱惑。中国古风仙侠，16-bit PC-98像素风格，暗红+黑色调。 | A desolate mountain path, a woman in black standing blocking the way, exuding suffocating pressure. Her eyes are deep as abysses, a tempting smile on her lips. The youth stands opposite, face grave. Tense and seductive atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, dark red-black tones, 832x1144 --ar 3:4 |
| `scene_ch_golden_80.png` | 道侣机缘 | 80 | 灵泉瀑布旁，修行身影转头对视 | 一处灵泉瀑布，水流如银练垂落，水雾中彩虹若隐若现。瀑布旁的石台上，一个修行身影转过头来，目光清亮。空气中弥漫着暧昧的情愫。氛围浪漫而宁静。中国古风仙侠，16-bit PC-98像素风格，青绿+粉白色调。 | A spirit spring waterfall, water cascading like silver silk, a rainbow faintly visible in the mist. On a stone platform beside the waterfall, a cultivation figure turns around, eyes clear and bright. An ambiguous affection fills the air. Romantic and serene atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, green-pink-white tones, 832x1144 --ar 3:4 |
| `scene_ch_golden_100.png` | 突破元婴 | 100 | 金丹碎裂，元婴将出，九死一生 | 丹田内视视角，金色圆丹正在碎裂，裂纹中透出耀眼的白光。一个婴儿般的光影在丹壳内挣扎欲出。剧痛让少年的面容扭曲。氛围惊险而宏大。中国古风仙侠，16-bit PC-98像素风格，金色碎裂+白金色光芒。 | Internal dantian view, the golden core cracking, brilliant white light seeping through the fractures. A baby-like light silhouette struggles to emerge from the shell. The youth's face contorts in agony. Thrilling and grand atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, golden shatters with platinum light, 832x1144 --ar 3:4 |

---

#### 第四章：碎丹成婴（元婴期 nascent）

| 文件名 | 标题 | 阈值 | 场景描述 | 中文提示词 | 英文提示词 |
|--------|------|------|---------|-----------|-----------|
| `scene_ch_nascent_20.png` | 元婴化形 | 20 | 元婴盘膝而坐，面目与修行者相同 | 内视视角，丹田内一个寸许大小的婴儿盘膝而坐，面目与少年一模一样，周身散发着柔和的银白色光芒。元婴睁开双眼，世界变得前所未有的清晰。氛围神奇而庄严。中国古风仙侠，16-bit PC-98像素风格，银白色调。 | Internal view, a palm-sized infant sitting cross-legged in the dantian, face identical to the youth, surrounded by soft silver-white light. The nascent soul opens its eyes, the world becoming unprecedentedly clear. Magical and solemn atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, silver-white tones, 832x1144 --ar 3:4 |
| `scene_ch_nascent_40.png` | 天劫预兆 | 40 | 深夜打坐时，天空雷光乍现劈落面前 | 深夜的山顶，少年盘坐于巨石之上。突然天空裂开，一道紫色雷电劈落在面前三寸，地面焦黑。远处云层中雷龙游走。氛围压迫而危机四伏。中国古风仙侠，16-bit PC-98像素风格，深紫+暗黑色调。 | Deep night on a mountain peak, the youth meditating on a giant boulder. Suddenly the sky splits, a purple lightning bolt striking three inches before him, the ground charred black. Thunder dragons coil in distant clouds. Oppressive and crisis-laden atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, deep purple-black tones, 832x1144 --ar 3:4 |
| `scene_ch_nascent_60.png` | 因果清算 | 60 | 因果轮盘转动，善恶因同时发芽 | 一个巨大的轮盘虚影悬浮在少年头顶，轮盘分为黑白两半，无数丝线从轮盘延伸出去，连接到远方的不同人物。有些丝线发着金光，有些散发着黑气。氛围神秘而宿命感强烈。中国古风仙侠，16-bit PC-98像素风格，黑白金对比色调。 | A massive wheel illusion hovering above the youth, divided into black and white halves, countless threads extending to distant figures. Some threads glow golden, others emit black qi. Mysterious and deeply fateful atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, black-white-gold contrast, 832x1144 --ar 3:4 |
| `scene_ch_nascent_80.png` | 宿命抉择 | 80 | 混沌漏洞体质，要么成仙要么成魔 | 天机阁观星台上，少年面前悬浮着一面巨大的铜镜，镜中显示着自己的灵根——残缺不全却被混沌之力修补。天机阁长老在身后警告。氛围沉重而命运感强烈。中国古风仙侠，16-bit PC-98像素风格，深蓝+银色调。 | On the Celestial Mechanism Pavilion's star-gazing platform, a massive bronze mirror hovers before the youth, showing his spiritual roots—incomplete yet patched by chaotic power. The elder warns from behind. Heavy and fateful atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, deep blue-silver tones, 832x1144 --ar 3:4 |
| `scene_ch_nascent_100.png` | 突破化神 | 100 | 元婴成长为元神，以精血为引 | 闭关密室，少年割破手指，血滴落入丹田。元婴沐浴在精血中，金光大放，逐渐成长为与少年等大的元神虚影。氛围神圣而血祭的悲壮。中国古风仙侠，16-bit PC-98像素风格，金色+血红色调。 | In a closed cultivation chamber, the youth cuts his finger, blood drops falling into the dantian. The nascent soul bathes in the blood, golden light erupting, gradually growing into a life-sized primordial spirit phantom. Sacred yet tragically sacrificial atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, gold with blood-red tones, 832x1144 --ar 3:4 |

---

#### 第五章：神游太虚（化神期 deity）

| 文件名 | 标题 | 阈值 | 场景描述 | 中文提示词 | 英文提示词 |
|--------|------|------|---------|-----------|-----------|
| `scene_ch_deity_20.png` | 化神之变 | 20 | 感知超越肉身，看到因果丝线灵气潮流 | 少年悬浮于半空，双眼发出白金光芒。无数半透明的丝线从他身上延伸出去，连接着天地万物。灵气如潮水般在天地间流动，远处的人心中的善恶如灯火般可见。氛围超然而恐怖。中国古风仙侠，16-bit PC-98像素风格，白金色调+半透明特效。 | The youth floating mid-air, eyes emitting platinum light. Countless semi-transparent threads extend from him, connecting to all things in heaven and earth. Spiritual energy flows like tides, the good and evil in distant hearts visible as lanterns. Transcendent yet terrifying atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, platinum with translucent effects, 832x1144 --ar 3:4 |
| `scene_ch_deity_40.png` | 上古秘辛 | 40 | 荒废遗迹中发现半块石碑记载混沌体质 | 荒废的上古遗迹，断壁残垣间爬满发光的藤蔓。少年面前矗立着半块巨大的石碑，碑文散发着古老的金光，记载着混沌漏洞的秘密。氛围沧桑而神秘。中国古风仙侠，16-bit PC-98像素风格，暗金+深绿色调。 | A ruined ancient site, glowing vines crawling over broken walls. Before the youth stands half of a massive stone stele, ancient inscriptions emitting golden light, recording the secrets of the chaotic loophole constitution. Ancient and mysterious atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, dark gold with deep green tones, 832x1144 --ar 3:4 |
| `scene_ch_deity_60.png` | 世界崩塌 | 60 | 天边出现空间裂缝，天道正在崩塌 | 天际出现一道巨大的裂缝，像天空被撕裂，露出后面虚无的黑暗。大地震动，山川崩塌，凡人在惊恐奔逃。少年立于高空，面色凝重地望着裂缝。氛围末日而绝望。中国古风仙侠，16-bit PC-98像素风格，暗红+深黑色调。 | A massive tear in the sky, like heaven being ripped open, revealing the void's darkness behind. The earth quakes, mountains crumble, mortals flee in terror. The youth stands in the high air, gazing gravely at the rift. Apocalyptic and desperate atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, dark red-black tones, 832x1144 --ar 3:4 |
| `scene_ch_deity_80.png` | 众生因果 | 80 | 看到每个人的因果线，与自己相连 | 少年站在云端，俯瞰大地。每个人身上都有丝线延伸而出，最终汇聚到自己身上。丝线的颜色代表着善恶因果——金色的善缘、黑色的恶缘、灰色的中立。氛围宏大而悲悯。中国古风仙侠，16-bit PC-98像素风格，多彩丝线+白云背景。 | The youth stands on clouds, overlooking the earth. Every person has threads extending from them, converging on him. Thread colors represent karmic connections—golden for good, black for evil, gray for neutral. Grand and compassionate atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, colorful threads with white cloud background, 832x1144 --ar 3:4 |
| `scene_ch_deity_100.png` | 突破渡劫 | 100 | 化神大圆满，天空乌云密布雷龙游走 | 少年立于万丈悬崖之巅，天空乌云密布，紫金色的雷龙在云层中穿梭咆哮。大地在颤抖，天地间的灵气都向少年汇聚。氛围宏大而肃杀。中国古风仙侠，16-bit PC-98像素风格，暗紫+雷光金色调。 | The youth stands atop a ten-thousand-zhang cliff, the sky covered in dark clouds, purple-gold thunder dragons roaring and weaving through the layers. The earth trembles, all spiritual energy in heaven and earth converging on him. Grand and solemn atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, dark purple with lightning-gold tones, 832x1144 --ar 3:4 |

---

#### 第六章：天劫飞升（渡劫期 tribulation）

| 文件名 | 标题 | 阈值 | 场景描述 | 中文提示词 | 英文提示词 |
|--------|------|------|---------|-----------|-----------|
| `scene_ch_tribulation_20.png` | 天劫降临 | 20 | 第一道劫雷劈落，紫金雷电直贯天灵 | 少年盘坐于渡劫台上，第一道紫金色的劫雷从天而降，直贯天灵盖。雷电的光芒照亮了整个天空，少年的衣袍在电光中猎猎作响。氛围惨烈而壮烈。中国古风仙侠，16-bit PC-98像素风格，紫金雷电+暗黑色调。 | The youth sits on a tribulation platform, the first purple-gold lightning bolt descending from the heavens, striking directly at the crown of his head. The lightning illuminates the entire sky, his robes fluttering in the electric light. Tragic and heroic atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, purple-gold lightning with dark tones, 832x1144 --ar 3:4 |
| `scene_ch_tribulation_40.png` | 九九雷劫 | 40 | 第四十道劫雷已过，劫雷蕴含造化 | 少年浑身焦黑但眼神清明，站在雷云之下。劫雷的颜色开始变化——从毁灭的紫黑色变成了蕴含造化的白金色。每一道雷落下后都有灵气漩涡形成。氛围坚韧而希望。中国古风仙侠，16-bit PC-98像素风格，白金+焦黑色调。 | The youth's body charred black but eyes clear, standing beneath the thunderclouds. The tribulation lightning changes color—from destructive purple-black to creative white-gold. Spiritual vortexes form after each strike. Resilient and hopeful atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, white-gold with charred black tones, 832x1144 --ar 3:4 |
| `scene_ch_tribulation_60.png` | 心魔大劫 | 60 | 第六十道劫雷劈在心上，心魔显形 | 少年的内心世界，一个与他面目完全相同但眼神充满愤恨的身影站在对面。周围是无数个记忆的碎片——每一次选择、每一道伤口都在空中漂浮。氛围诡异而内省。中国古风仙侠，16-bit PC-98像素风格，暗红+镜像对比色调。 | The youth's inner world, a figure identical in face but filled with hatred in the eyes stands opposite. Countless memory fragments float around—every choice, every wound. Eerie and introspective atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, dark red with mirror-contrast tones, 832x1144 --ar 3:4 |
| `scene_ch_tribulation_80.png` | 最后抉择 | 80 | 第八十道劫雷后看到仙界入口和凡间少年 | 天地之间一片寂静，一道天光从裂缝中射出——那是仙界的入口。但少年看到了过去的自己——那个灵根残缺的少年站在废弃道观中。两个时空重叠在一起。氛围宿命而抉择。中国古风仙侠，16-bit PC-98像素风格，天光金+回忆朦胧色调。 | Silence between heaven and earth, a celestial light shooting from a rift—the entrance to the immortal realm. But the youth sees his past self—the spiritually deficient youth standing in the ruined temple. Two timelines overlap. Fateful and decisive atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, celestial gold with nostalgic haze, 832x1144 --ar 3:4 |
| `scene_ch_tribulation_100.png` | 飞升陨落 | 100 | 最后一道九九归一雷，决定一切 | 天地之间只剩下一道雷——九九归一雷。这道雷中包含了少年所有的因果、师友、仇敌、爱人和过往。雷光中仿佛能看到无数面孔。氛围终极而宏大。中国古风仙侠，16-bit PC-98像素风格，纯白+彩虹色边缘。 | Only one lightning bolt remains between heaven and earth—the Nine-Nine Unity Thunder. This bolt contains all the youth's karma, friends, enemies, lovers, and past. Countless faces seem visible within the lightning. Ultimate and grand atmosphere. Chinese xianxia, 16-bit PC-98 pixel art, pure white with rainbow edges, 832x1144 --ar 3:4 |

---

## 三、画风统一规范

### 3.1 技术规格

| 参数 | 要求 |
|------|------|
| **分辨率** | 832×1144 像素 |
| **格式** | PNG（场景图/角色卡）/ WebP（概念图） |
| **色彩深度** | 8-bit RGB |
| **画风** | 16-bit PC-98 复古像素风格 / 水墨古风 |
| **背景处理** | 支持透明或纯色背景（根据用途） |

### 3.2 色调递进表

| 境界 | 主色调 | 辅助色 | 氛围关键词 |
|------|--------|--------|-----------|
| 炼气期 | 青蓝 `#4a9eff` | 白 `#ffffff` | 初醒、期待、神秘 |
| 筑基期 | 翠绿 `#2ecc71` | 白玉 `#f5f5f5` | 成长、宗门、纷争 |
| 金丹期 | 金橙 `#f39c12` | 暗红 `#c0392b` | 成熟、抉择、诱惑 |
| 元婴期 | 紫红 `#9b59b6` | 银白 `#ecf0f1` | 超脱、因果、宿命 |
| 化神期 | 白金 `#f1c40f` | 深蓝 `#2c3e50` | 神游、崩塌、悲悯 |
| 渡劫期 | 暗红 `#e74c3c` | 雷金 `#f1c40f` | 雷劫、心魔、终极 |

### 3.3 提示词通用后缀（适用于所有 AI 绘画工具）

**中文通用后缀：**
```
，中国古风仙侠风格，16-bit PC-98复古像素风格，像素艺术，低饱和度，832x1144像素，--ar 3:4
```

**英文通用后缀（Midjourney）：**
```
, Chinese xianxia fantasy style, 16-bit PC-98 retro pixel art style, pixel art, low saturation, 832x1144 --ar 3:4 --niji 6
```

**英文通用后缀（Stable Diffusion）：**
```
, chinese xianxia fantasy, pc-98 pixel art style, 16-bit, pixelart, muted colors, masterpiece, best quality, 832x1144
Negative prompt: 3d render, realistic, photorealistic, western style, modern clothes, lowres, blurry
```

---

## 四、推荐生成工具

| 工具 | 适用类型 | 优点 | 缺点 |
|------|---------|------|------|
| **Midjourney v6** | 概念图、场景图 | 氛围感强，风格统一 | 需订阅，不可控像素风 |
| **Stable Diffusion XL** | 全部 | 本地运行，可训练LoRA | 需显卡，配置复杂 |
| **即梦（Dreamina）** | 全部 | 中文支持好，免费额度多 | 风格一致性一般 |
| **通义万相** | 全部 | 中文场景理解好 | 仙侠风格需调参 |
| **可灵AI** | 全部 | 视频+图片，国产友好 | 新工具，稳定性待验证 |

### 推荐工作流

1. **概念图**（concept_*.webp）：用 Midjourney / 即梦 生成动漫风格立绘
2. **场景图**（scene_*.png）：用 Stable Diffusion + PixelArt LoRA 生成像素风场景
3. **诱惑立绘**（*_seductive.*）：用 Midjourney / 即梦，注意控制生成尺度
4. **统一后期**：用 Photoshop/Photopea 统一调色到目标色调递进表

---

## 五、批量生成脚本（Python）

如果你使用 Stable Diffusion 的 API，可以使用以下批量生成脚本：

```python
# 将此脚本保存为 batch_generate.py，放在 Stable Diffusion webui 目录下运行
import requests
import os

SCENES = [
    # (文件名, 英文提示词, 境界色调)
    ("scene_ch_qi_20.png", "young cultivator meditating, cyan spiritual light from dantian...", "cyan"),
    # ... 填入全部30个场景
]

API_URL = "http://localhost:7860/sdapi/v1/txt2img"

for filename, prompt, color_tone in SCENES:
    payload = {
        "prompt": prompt + ", chinese xianxia fantasy, pc-98 pixel art, 16-bit, masterpiece",
        "negative_prompt": "3d render, realistic, photorealistic, western, modern",
        "width": 832,
        "height": 1144,
        "steps": 30,
        "cfg_scale": 7,
        "sampler_name": "DPM++ 2M Karras"
    }
    # ... 发送请求并保存
```

---

*本清单由自动化扫描工具生成，覆盖全部34个缺失文件。如有新增资源引用，可重新运行扫描脚本更新。*
