# -*- coding: utf-8 -*-
"""从 manifest.json 渲染出可直接交付画画 Agent 的完整对接文档。

单一真相源：所有 prompt 只存在于 manifest.json，本脚本只做渲染，
因此文档不会与配置漂移。manifest 改动后重跑即可。

用法：
    python tools/render_painter_handoff.py
    python tools/render_painter_handoff.py --check   # 只校验是否已同步
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BRIEF_DIR = os.path.join(ROOT, "art_brief", "treasure_icons_v1")
MANIFEST = os.path.join(BRIEF_DIR, "manifest.json")
OUTPUT = os.path.join(BRIEF_DIR, "PAINTER_HANDOFF.md")

SLOT_ZH = {"weapon": "兵刃", "armor": "护具", "accessory": "佩饰", "artifact": "秘宝"}
ORDER = ["weapon", "armor", "accessory", "artifact"]


def load():
    with open(MANIFEST, encoding="utf-8") as fh:
        return json.load(fh)


def render(m: dict) -> str:
    d = m["delivery"]
    c = m["canvas"]
    gs = m["globalStyle"]
    ct = m["colorTokens"]
    items = m["items"]

    L = []
    a = L.append

    a("# 法宝图标绘制对接单")
    a("")
    a("> 这份文档自包含，读完即可开工。**18 张图，一张不多一张不少。**")
    a("> 规则详解与「其他素材为什么不用画」见同目录 `BRIEF.md`；")
    a("> 机器可读配置见 `manifest.json`（本文件由它渲染，两者内容一致）。")
    a("")
    a("| 项 | 内容 |")
    a("|---|---|")
    a("| 项目 | %s |" % m["project"])
    a("| 引擎 | %s（运行时按 nearest 缩到 26×26 显示） |" % m["engine"])
    a("| 用途 | %s |" % m["purpose"])
    a("| 数量 | **%d 张**，覆盖 55 件法宝 |" % d["totalFiles"])
    a("| 生成日期 | %s |" % m["createdAt"])
    a("")

    a("---")
    a("")
    a("## 一、你现在要做什么")
    a("")
    a("画 **%d 个独立的像素风小图标**，每个都是一件中国修仙题材的器物。" % d["totalFiles"])
    a("深色描边、全透明背景、无外框、无发光，缩到 26 像素还能一眼认出是什么东西。")
    a("")
    a("**参照风格**：`godot/content/assets/icons/icon_lifespan.png`（64×64 像素图标）、")
    a("`godot/content/assets/icons/icon_linggen_huo.png`（64 网格像素画放大到 1024）。")
    a("这批新图必须是同一套语言——**是像素画，不是手绘插画，不是 3D 渲染**。")
    a("")

    a("## 二、落盘位置（18 张全放同一个目录）")
    a("")
    a("```")
    a(d["outputDirAbsolute"])
    a("```")
    a("")
    a("| 用途 | 路径写法 |")
    a("|---|---|")
    a("| 绝对路径 | `%s` |" % d["outputDirAbsolute"])
    a("| 引擎内路径 | `%s` |" % d["enginePathPrefix"])
    a("| 数据引用写法 | `%s` |" % d["jsonRefPrefix"])
    a("| 命名规则 | `%s` |" % d["filePattern"])
    a("")
    a("**文件名一个字都不能改**，代码按 `{槽位}_{品阶}` 拼路径。目录不存在就新建。")
    a("")

    a("## 三、画布与输出规格（硬约束）")
    a("")
    a("| 项 | 要求 |")
    a("|---|---|")
    a("| 画布 | **%d × %d px** |" % (c["outputPixels"], c["outputPixels"]))
    a("| 逻辑网格 | **%d × %d** |" % (c["logicalGrid"], c["logicalGrid"]))
    a("| 单格大小 | **%d × %d px** 实心块 |" % (c["pixelBlock"], c["pixelBlock"]))
    a("| 抗锯齿 | **零**。alpha 只有 0 或 255，不允许任何半透明过渡像素 |")
    a("| 背景 | 完全透明，四角 alpha = 0 |")
    a("| 格式 | PNG，RGBA |")
    a("")
    a("> 为什么是 512 / 64 / 8：512 = 64 × 8，所以每个逻辑像素正好 8×8 实心块。")
    a("> 缩到 26×26 时不会出现半像素和模糊。**不要输出 1024 或任何非 8 倍数的画布。**")
    a("")

    a("## 四、画风硬约束")
    a("")
    a("项目美术母语（摘自 `docs/ART_DIRECTION_BIBLE_v1.md`）：")
    a("")
    a("> **%s**" % gs["lineage"])
    a("")
    a("落到这批图标上：")
    a("")
    a("| 维度 | 要求 |")
    a("|---|---|")
    a("| 技法 | 手绘像素画。硬边色块 + 受控抖色。禁止平滑喷枪、禁止羽化 |")
    a("| 描边 | %s |" % gs["outline"])
    a("| 色数 | 单图 **不超过 %s**（见品阶分级） |" % gs["paletteLimit"].replace("单图不超过 ", ""))
    a("| 背景 | 完全透明 |")
    a("| 外框 | **不画**边框、圆角徽章、卡片底、圆形底盘 |")
    a("| 光照 | 无发光、无 bloom、无边缘光、无镜头光斑。体积只靠色块明度差 |")
    a("| 构图 | 单一物件居中，占画布约 78%，四周留 6 逻辑像素安全区 |")
    a("| 可读性 | 缩到 **26×26** 仍能一眼分辨物件类别 |")
    a("")
    a("**禁止进入画面**：%s" % gs["forbidden"])
    a("")

    a("### 调色板（只准用这些色）")
    a("")
    a("| token | 色值 | 用途 |")
    a("|---|---|---|")
    a("| 墨 | `%s` | 描边、最深阴影 |" % ct["ink"])
    a("| 纸 | `%s` | 亮面、布、纸 |" % ct["paper"])
    a("| 灰纸 | `%s` | 铁、石、次级亮面 |" % ct["mutedPaper"])
    a("| 冷玉 | `%s` | 玉、灵气、正道物件 |" % ct["jade"])
    a("| 旧金 | `%s` | 铜件、包角、环扣 |" % ct["brass"])
    a("| 深旧金 | `%s` | 青铜暗部、木胎 |" % ct["deepBrass"])
    a("| 朱砂 | `%s` | **只用于危险/仙品点缀**，全图不超过一处 |" % ct["cinnabar"])
    a("| 冷白 | `%s` | 极少量高光，1~4 像素 |" % ct["coldWhite"])
    a("")

    a("### 品阶视觉分级（必须能一眼区分）")
    a("")
    a("| 品阶 | 语言 |")
    a("|---|---|")
    for k in sorted(m["rarityLanguage"], key=lambda x: int(x)):
        a("| r%s | %s |" % (k, m["rarityLanguage"][k]))
    a("")

    a("## 五、统一负向提示词（每张都要带）")
    a("")
    a("```")
    a(m["globalNegative"])
    a("```")
    a("")
    a("---")
    a("")

    a("## 六、逐项绘制指令")
    a("")
    a("按槽位分组。每项含：落盘路径、画什么、可直接复制的正向 prompt、该张专项验收。")
    a("")

    n = 0
    for slot in ORDER:
        group = [it for it in items if it["slot"] == slot]
        if not group:
            continue
        a("### %s（%d 张，覆盖 %d 件法宝）" % (
            SLOT_ZH.get(slot, slot), len(group), sum(it["count"] for it in group)))
        a("")
        for it in group:
            n += 1
            a("#### %02d. `%s`  · %s r%s" % (n, it["fileName"], it["rarityZh"], it["rarity"]))
            a("")
            a("| 项 | 内容 |")
            a("|---|---|")
            a("| 落盘绝对路径 | `%s` |" % it["absoluteOutputPath"])
            a("| 引擎路径 | `%s` |" % it["enginePath"])
            a("| 覆盖法宝 | %s（共 %d 件） |" % ("、".join(it["coversTreasures"]), it["count"]))
            a("| 建议用色 | %s |" % "、".join("`%s`" % p for p in it["paletteHint"]))
            a("")
            a("**画什么**：%s" % it["subjectZh"])
            a("")
            a("正向 prompt（复制即用）：")
            a("")
            a("```")
            a(it["prompt"])
            a("```")
            a("")
            a("负向 prompt：")
            a("")
            a("```")
            a(m["globalNegative"])
            a("```")
            a("")
            a("该张专项验收：")
            a("")
            for acc in it["acceptance"]:
                a("- %s" % acc)
            a("")

    a("---")
    a("")
    a("## 七、交付流程")
    a("")
    a("**不要一次画完 18 张。** 先交这 3 张做风格校准：")
    a("")
    a("| 顺序 | 文件 | 为什么是它 |")
    a("|---|---|---|")
    a("| 1 | `artifact_4.png` | 单张覆盖 16 件法宝，最该画精 |")
    a("| 2 | `weapon_4.png` | 覆盖 6 件，兵刃里最常出现 |")
    a("| 3 | `armor_2.png` | 18 张里最简的一张，用来确认下限 |")
    a("")
    a("这 3 张确认通过后，再批量出剩余 15 张。")
    a("")

    a("## 八、交付后由工程侧执行（你不用管）")
    a("")
    a("1. 图放进 `items\\` 目录后**立刻生效**，不需要改代码、不需要重启编辑器")
    a("2. 工程侧跑自动校验：")
    a("")
    a("```bash")
    a("cd <repo>/godot && python tools/validate_treasure_icons.py")
    a("# 期望 TREASURE_ICONS_PASS files=18/18")
    a("```")
    a("")
    a("3. 校验通过后接图鉴与坊市列表，并做 26px 可辨认性截图比对")
    a("")
    a("> **提醒**：不要去 `content/data/shops/treasures.json` 里加 `icon` 字段。")
    a("> 那份数据被 `source_manifest.json` 按 sha256 + bytes 硬绑定，")
    a("> 改一个字节就会让内容索引整体失败。代码走的是路径约定，不需要数据配合。")
    a("")

    a("## 九、常见错误（会直接被校验脚本打回）")
    a("")
    a("| 症状 | 原因 | 正确做法 |")
    a("|---|---|---|")
    a("| `not aligned to 8x8 block` | 用了抗锯齿或羽化，或画布不是 8 的倍数 | 关闭抗锯齿，按 64 网格落笔 |")
    a("| `semi-transparent pixels` | 用了透明度渐变 | alpha 只允许 0 或 255 |")
    a("| `colors=17 > 16` | 高光叠太多层 | 按调色板取色，上限 16 色 |")
    a("| `corner xx not transparent` | 铺了底色或画布底 | 背景完全透明 |")
    a("| `size=1024x1024` | 输出尺寸错 | 统一 512×512 |")
    a("| 26px 下一团黑 | 细节过密 | 主体占 78%，减少内部纹理 |")
    a("")
    a("---")
    a("")
    a("**文档来源**：由 `tools/render_painter_handoff.py` 从 `manifest.json` 渲染，")
    a("共 %d 项。修改 prompt 请改 manifest 后重新渲染，不要直接改本文件。" % len(items))
    a("")

    return "\n".join(L)


def main() -> int:
    m = load()
    text = render(m)
    if "--check" in sys.argv:
        if not os.path.isfile(OUTPUT):
            print("PAINTER_HANDOFF_MISSING")
            return 1
        with open(OUTPUT, encoding="utf-8") as fh:
            cur = fh.read()
        if cur != text:
            print("PAINTER_HANDOFF_STALE (re-run without --check)")
            return 1
        print("PAINTER_HANDOFF_IN_SYNC items=%d" % len(m["items"]))
        return 0
    os.makedirs(BRIEF_DIR, exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    print("WROTE %s items=%d bytes=%d" % (OUTPUT, len(m["items"]), len(text.encode("utf-8"))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
