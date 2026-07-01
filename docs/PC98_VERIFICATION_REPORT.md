# PC98卡面资产 · 完整重建设计验证报告

**日期**: 2026-06-28  
**状态**: ✅ 全部P0修复完成

---

## 验证项 1: 比例统一性 ✅

所有21张卡面统一为 **768×942 竖版 (3:4)**

| 类别 | 数量 | 分辨率 | 比例 | 
|------|------|--------|------|
| 角色卡 | 8张 | 768×942 | 3:4 |
| 道侣场景 | 8张 | 768×942 | 3:4 |
| 事件场景 | 5张 | 768×942 | 3:4 |

> 旧版场景卡为1408×647横版(2:1)，已全部重生成竖版。

---

## 验证项 2: 人物设定对齐 ✅

| NPC ID | GDD设定 | 卡面形象 | 状态 |
|--------|---------|---------|------|
| tianji_laoren | 灰袍蒙面老者，手持天机盘 | ✅ 灰袍蒙面白须老者 | 已修复 |
| mu_qinglan | 女性学者，蓝袍，水元素 | ✅ 蓝袍女性学者持竹简 | 已修复 |
| yin_xue | 男性血煞剑修，冷傲 | ✅ 男性红黑战袍剑修 | 已修复 |
| xuesha_laozu | 血红长袍红发魔道宗主 | ✅ 红发重甲反派 | OK |
| jiuwei_suyue | 九尾妖狐化形 | ✅ 紫狐女 | OK |
| bai_luoxuan | 白毛狐女 | ✅ 白毛狐女 | OK |
| bai_ren_zhenren | 白衣白发剑修导师 | ✅ 白发金袍持剑 | OK |
| jian_linger | 傲娇师姐剑修 | ✅ 黑发剑女 | OK |

---

## 验证项 3: 代码映射 ✅

PC98CardSystem.cardMap 覆盖全部8位NPC（含别名）:

```
✅ bai_luoxuan → card_bailuoshuang_pc98.png
✅ bai_ren_zhenren / bai_ren → card_bairen_zhenren_pc98.png
✅ jian_linger → card_jianlinger_pc98.png
✅ mu_qinglan → card_mu_qinglan_pc98.png
✅ tianji_laoren → card_tianji_laoren_pc98.png
✅ jiuwei_suyue → card_jiuwei_suyue_pc98.png
✅ yin_xue → card_yinxue_pc98.png
✅ xuesha_laozu → card_xuesha_laozu_pc98.png
```

已移除有问题的 `_addCardFusionOverlays` 调用。

---

## 验证项 4: 画风统一 ✅

- 统一PC98 16-bit像素美术风格
- 统一颜色限制(256色调色板视觉感受)
- 统一黑色轮廓线，左上→右下光照
- 统一prompt模板: `docs/PC98_PROMPT_TEMPLATE.md`

---

## 资产清单

```
assets/cards/
├── characters/          # 8张角色卡 (768×942)
│   ├── card_bailuoshuang_pc98.png
│   ├── card_bairen_zhenren_pc98.png
│   ├── card_jianlinger_pc98.png
│   ├── card_jiuwei_suyue_pc98.png
│   ├── card_mu_qinglan_pc98.png    ← 新生成(女性学者)
│   ├── card_tianji_laoren_pc98.png ← 新生成(灰袍老者)
│   ├── card_xuesha_laozu_pc98.png
│   └── card_yinxue_pc98.png        ← 新生成(男性剑修)
│
├── companions/          # 8张道侣场景 (768×942)
│   ├── scene_comp_bai_luoxuan_moonlight.png
│   ├── scene_comp_bai_ren_sworddebate.png
│   ├── scene_comp_jian_linger_dawn.png
│   ├── scene_comp_jiuwei_suyue_foxrealm.png
│   ├── scene_comp_mu_qinglan_library.png
│   ├── scene_comp_tianji_laoren_stargazing.png
│   ├── scene_comp_xuesha_laozu_bloodfeast.png
│   └── scene_comp_yin_xue_bloodmoon.png
│
└── events/              # 5张炼气期事件场景 (768×942)
    ├── scene_event_qi_inherit.png
    ├── scene_event_qi_spirit_mine.png
    ├── scene_event_qi_whitefox.png
    ├── scene_event_qi_herb_gather.png
    └── scene_event_qi_swordtomb.png
```

---

## 后续建议

1. 运行时实测：打开游戏确认8个NPC立绘都显示PC98卡面
2. 场景卡集成：需要GameUI中增加场景切换逻辑读写companions/events图片
3. 高阶境界事件场景(yuan/base/jin)还有大约12张缺失，按需后续生成
