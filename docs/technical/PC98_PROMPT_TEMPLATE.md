# PC98 卡面生成 · 统一 Prompt 模板

## 基数规范
- **分辨率**: 1024×1536 (生成后裁剪为 768×942，顶部裁到底部水印以上)
- **比例**: 3:4 竖版
- **风格**: PC98 16-bit 像素艺术 × 仙侠修真世界观
- **水印处理**: 底部 8% 裁剪

## 统一画风约束

### 必须遵守
- 像素颗粒均匀（16-bit 精度），不混入高清渲染
- 色板限制在 PC98 调色板范围（256 色视觉感受）
- 黑色轮廓线清晰，明暗对比分明
- 角色占据画面 60-70%，上下留呼吸空间
- 背景简化——单色/渐变/简单纹样，不抢角色
- 光照方向统一左上→右下

### 禁止
- 禁止高清/写实/3D渲染风格
- 禁止文字、标签、UI 元素出现在画面中
- 禁止复杂背景（场景卡除外）
- 禁止不同角色之间的画风跳变（日系/欧美/厚涂）

---

## 角色卡 Prompt 模板

```
[CHARACTER_DESCRIPTION], full body character card, PC98 pixel art style, 
16-bit retro game aesthetic, limited color palette, crisp pixel edges, 
black outlines, dramatic lighting from top-left, vertically centered composition, 
solid muted background with subtle pattern, 
xianxia cultivation theme, portrait aspect ratio 3:4, 
no text no UI no watermark

参考品质对标：Dead Cells 的像素精度 × Hyper Light Drifter 的色彩氛围， 
融合仙侠修真世界观的符号系统（飞剑、灵气、符箓、阵纹）
```

---

## 场景卡 Prompt 模板

```
[SCENE_DESCRIPTION], atmospheric xianxia scene, PC98 pixel art style,
16-bit retro game aesthetic, limited color palette, crisp pixel edges,
layered depth with foreground silhouette elements,
dramatic mood lighting, subtle particle effects for atmosphere,
solid border frame, portrait aspect ratio 3:4,
no text no UI no watermark

场景氛围参考：《轩辕剑》系列像素场景 × 像素艺术中的光影层次，
保留前景暗影剪裁增强景深感
```

---

## 角色 Prompt 参数表（严格基于 GDD v1.0 设定）

### 天机老人（老者·男性）
```
character_prompt: "elderly male cultivator in grey hooded robe, face partially hidden,
holding a fragmented celestial divination disk (tianji pan), 
surrounding space subtly warped with distortion ripples, 
white beard visible beneath hood, ancient wise eyes, 
mysterious and enigmatic aura, full body standing pose"
```

### 慕青岚（青年·女性）
```
character_prompt: "young female cultivator scholar, elegant blue scholarly robes,
holding an ancient bamboo scroll in one hand, water-element spiritual energy swirling around,
intelligent calm expression, classic beauty with hair in simple bun held by jade hairpin,
cool rational demeanor, standing in library-like setting with scroll shelves silhouetted behind,
full body standing pose"
```

### 殷血（青年·男性）
```
character_prompt: "young male demonic sword cultivator, cold arrogant stance,
dark red and black battle robes, blood-red spiritual energy aura,
one hand resting on sword hilt, piercing sharp eyes,
lean muscular build, lone warrior aura, 
blood mist atmosphere, full body standing pose,
tall and imposing"
```

---

## 场景 Prompt 参数表

### 道侣场景（一律竖版768×942）

**白落霜·月色**
```
scene: "moonlit bamboo grove clearing, white fox tail silhouette in foreground,
silver moonlight filtering through leaves, gentle mist over still pond,
silver and jade color palette, serene romance atmosphere,
fairy-like ethereal glow particles"
```

**百刃真人·论剑**
```
scene: "mountain peak sword arena at dawn, ancient stone platform,
sword energy trails cutting through morning clouds, golden sunrise light,
one upright sword planted in center of platform, distant mountain peaks silhouettes,
golden and steel-blue color palette, solemn dignified atmosphere"
```

**剑灵儿·黎明**
```
scene: "cliff edge overlooking misty valley at dawn, sword practice training ground,
scattered sword marks on ancient stone, early morning golden light,
wind-blown cherry blossom petals, sword rack silhouette in foreground,
pink and gold color palette, youthful determined atmosphere"
```

**殷血·血月**
```
scene: "blood-red moon over desolate battlefield, demonic sword altar,
crimson energy vortex spiraling upward, broken weapons scattered on ground,
dark silhouette of lone figure standing before altar,
deep red and black color palette, dark intense atmosphere"
```

**九尾溯月·狐域**
```
scene: "mystical fox realm at twilight, nine-tailed fox silhouette in moonlight,
ancient spirit tree with glowing foxfire wisps, stone torii gate entrance,
purple and silver color palette, mystical enchanting atmosphere,
foxfire particles floating in air"
```

**慕青岚·书阁**
```
scene: "ancient library interior at night, endless scroll shelves reaching into darkness,
candle-lit reading desk with scattered manuscripts, blue spirit energy flowing like water,
ink stone and brush on desk, arched window showing starry night sky,
deep blue and warm candle-gold color palette, quiet scholarly atmosphere"
```

**天机老人·观星**
```
scene: "observatory tower top at night, celestial divination disk floating above stone altar,
constellation patterns tracing across star-filled sky, ancient bronze astronomical instruments,
void-splitting starlight beams, reality distortion ripples near the disk,
deep indigo and gold color palette, cosmic mysterious atmosphere"
```

**血煞老祖·血宴**
```
scene: "blood demon sect hall interior, crimson ritual formation burning on floor,
blood-red candles lining stone altar, shadowy cultist figures in background,
ancient demonic statue looming, blood mist atmosphere,
deep red and obsidian black color palette, oppressive dark atmosphere"
```

### 炼气期事件场景

**前辈遗泽 (qi_inherit)**
```
scene: "ancient cave dwelling entrance, skeleton of deceased cultivator in meditation pose,
storage pouch glowing with spiritual light, moss-covered stone walls, 
sunlight beam piercing through cave ceiling crack, dust particles in light,
earth-tone and warm gold color palette, mysterious discovery atmosphere"
```

**灵石矿脉 (qi_spirit_mine)**
```
scene: "underground spirit stone mine tunnel, crystal veins glowing in walls,
pickaxe marks on stone, lantern light casting long shadows,
spirit stones of various colors embedded in rock, mine cart silhouette,
crystalline blue and warm lantern-orange color palette, resource gathering atmosphere"
```

**白狐求助 (qi_whitefox)**
```
scene: "mountain forest path at dusk, injured white fox with glowing faint aura,
hunter's trap visible nearby, concerned cultivator silhouette approaching,
fireflies starting to emerge, autumn leaves scattered on ground,
warm orange and white color palette, tender encounter atmosphere"
```

**采药 (qi_herb_gather)**
```
scene: "misty mountain herb garden at dawn, rare glowing spirit herbs among rocks,
dew drops sparkling, small waterfall in background, climbing vines on cliff face,
collector's basket and sickle silhouette in foreground,
emerald green and mist-grey color palette, peaceful gathering atmosphere"
```

**剑冢秘境 (qi_swordtomb)**
```
scene: "ancient sword graveyard at twilight, countless broken swords planted in ground,
ghostly sword energy wisps rising, central pedestal with sealed sword,
ancient stone formations, eerie blue spirit flames floating,
steel-blue and ghost-white color palette, solemn mysterious atmosphere"
```
