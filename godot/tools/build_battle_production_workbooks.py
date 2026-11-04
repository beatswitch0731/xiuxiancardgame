"""Generate source-backed scene, card-action and equipment production ledgers.

The workbooks describe *coverage and work remaining*. They never approve art,
invent a runtime scene, or change game content. Edit canonical data/ or the
authored module taskbooks, then regenerate; do not hand-edit generated rows.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "art_direction" / "production"
INPUTS = {
    "encounters": "data/combat/encounters.json",
    "encounter_presentations": "data/combat/encounter_presentations.json",
    "migrated_presentations": "data/combat/migrated_presentations.json",
    "stage_catalog": "godot/art_direction/battlefield_art_catalog.json",
    "actions": "data/combat/action_presentations.json",
    "cards": "data/cards/battle_cards.json",
    "treasures": "data/shops/treasures.json",
    "paths": "data/config/paths.json",
    "qi_threads": "data/threads/qi_threads.json",
}
PATH_IDS = ("sword", "spell", "body", "pill")
SLOTS = ("weapon", "armor", "accessory", "artifact")


def read(relative: str) -> dict:
    return json.loads((ROOT / relative).read_text(encoding="utf-8-sig"))


def cell(value: object) -> str:
    return str(value if value is not None else "").replace("|", "\\|").replace("\n", " ").strip()


def fingerprint() -> str:
    digest = hashlib.sha256()
    for path in sorted(INPUTS.values()):
        digest.update(path.encode("utf-8"))
        digest.update((ROOT / path).read_bytes())
    return digest.hexdigest()


def source_header(title: str, sha: str) -> list[str]:
    return [f"# {title}", "", "自动生成的制作盘点，不是美术通过或可玩证明。",
            f"来源集合 SHA-256：`{sha}`；重建：`python godot/tools/build_battle_production_workbooks.py`。",
            "规则与实施步骤见同目录的各专项任务书；此文件的表格不要手改。", ""]


def unique_rows(rows: list[dict], kind: str) -> dict[str, dict]:
    result: dict[str, dict] = {}
    for row in rows:
        key = row.get("id")
        if not isinstance(key, str) or not key or key in result:
            raise ValueError(f"{kind} 缺少唯一 ID：{key!r}")
        result[key] = row
    return result


def consequence(effects: object) -> str:
    if not isinstance(effects, dict) or not effects:
        return "来源未定义"
    return "、".join(f"{key}={value}" for key, value in sorted(effects.items()))


def build_scene_workbook(data: dict, sha: str) -> str:
    encounters = unique_rows(data["encounters"]["encounters"], "encounter")
    story_choices: dict[str, dict] = {}
    for thread in data["qi_threads"].get("threads", []):
        for node in thread.get("nodes", []):
            card = node.get("card", {})
            for direction, choice in card.get("choices", {}).items():
                if choice.get("triggerCombat"):
                    story_choices[f"{card.get('id')}:{direction}"] = choice
    catalogs = {
        "encounter": data["encounter_presentations"]["presentations"],
        "migrated_choice": data["migrated_presentations"]["presentations"],
    }
    stages = data["stage_catalog"]["battlefields"]
    seen_sources: set[tuple[str, str]] = set()
    scene_count = sum(bool(entry.get("runtimeScene")) for entry in stages.values())
    lines = source_header("剧情战场与敌人逐项制作台账", sha)
    lines += [
        f"源目录：{len(encounters)} 个遭遇、{sum(map(len, catalogs.values()))} 条展示、"
        f"{len(stages)} 个独立战场 ID；当前有运行场景的 ID：{scene_count}。",
        "每一行先保留来源卡、敌人、机制和原图，再制作空间草图、敌人造型、实体场景与完整回放。"
        "同一个战场 ID 可以对应不同分支展示，但分支不能换掉剧情地点。", "",
        "| 来源选择 / 遭遇 | 战场 ID · 制作族 | 敌人身份 | 战斗机制与空间设计依据 | 来源胜/败/逃与后续 | 实机状态 |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for battlefield_id, stage in sorted(stages.items()):
        for source in stage.get("sources", []):
            kind, key = source.get("sourceKind"), source.get("sourceKey")
            if kind not in catalogs or key not in catalogs[kind]:
                raise ValueError(f"战场 {battlefield_id} 指向不存在的来源 {kind}:{key}")
            presentation = catalogs[kind][key]
            if (kind, key) in seen_sources:
                raise ValueError(f"重复的展示来源：{kind}:{key}")
            seen_sources.add((kind, key))
            if presentation.get("battlefieldId") != battlefield_id or (
                presentation.get("presentationId") != source.get("presentationId")
                or presentation.get("sceneImage") != source.get("sceneImage")
            ):
                raise ValueError(f"战场 {battlefield_id} 的来源身份漂移：{kind}:{key}")
            encounter = encounters.get(key, {}) if kind == "encounter" else {}
            if kind == "encounter" and not encounter:
                raise ValueError(f"展示指向不存在的遭遇：{key}")
            actor = presentation.get("actorCards", {}).get("enemy", {})
            enemy = actor.get("name") or encounter.get("enemy", {}).get("name") or presentation.get("enemyType")
            if not enemy:
                raise ValueError(f"敌人身份缺失：{key}")
            mechanic = presentation.get("mechanic") or encounter.get("mechanic")
            conflict_note = ""
            story_choice = story_choices.get(key, {}) if kind == "migrated_choice" else {}
            story_mechanic = story_choice.get("combatPresentation", {}).get("mechanic", "")
            if story_mechanic:
                if mechanic and mechanic != story_mechanic:
                    conflict_note = "【迁移展示机制与原剧情冲突，按原剧情制作】"
                mechanic = story_mechanic
            elif kind == "migrated_choice":
                conflict_note = "【仅迁移展示机制；原剧情分支待逐项核对】"
            if not mechanic:
                raise ValueError(f"战斗机制缺失：{key}")
            brief = stage.get("designBrief", {})
            location = brief.get("canonicalStoryLocation") or brief.get("identity") or source.get("title")
            status = stage.get("artStatus", "unbuilt")
            if stage.get("runtimeScene"):
                status += " · 可加载，视觉仍待审"
            else:
                status += " · 无运行场景"
            outcome = encounter if kind == "encounter" else story_choice
            next_card = encounter.get("combatOutcomePresentation", {}).get(
                "victory", {}).get("nextCard", "") if kind == "encounter" else ""
            consequence_text = "胜: %s；败: %s；逃: %s%s" % (
                consequence(outcome.get("victoryEffects")),
                consequence(outcome.get("defeatEffects")),
                consequence(outcome.get("fleeEffects")),
                "；胜后: " + next_card if next_card else "")
            if kind == "migrated_choice" and not story_choice:
                consequence_text = "原剧情分支回写待逐项定位；不可由展示文案推断"
            lines.append("| " + " | ".join(map(cell, (
                f"{kind}:{key}", f"{battlefield_id} / {stage.get('productionFamily', '')}",
                enemy, f"{location}；{mechanic}{conflict_note}", consequence_text, status))) + " |")
    expected = {(kind, key) for kind, catalog in catalogs.items() for key in catalog}
    if seen_sources != expected:
        raise ValueError(f"展示覆盖缺口：{sorted(expected - seen_sources)}")
    lines += ["", "每行的完整来源图、presentationId、敌人尺度和既有独立草图状态，"
              "以 `battlefield_art_catalog.json` 为准。当前台账只锁身份和任务，不替代独立关卡构图。", ""]
    return "\n".join(lines)


def path_for(card: dict) -> str:
    declared = [path for path in PATH_IDS if path in card.get("tags", [])]
    return "+".join(declared) if declared else "通用/跨修"


def combat_beat(card: dict) -> str:
    kinds = [effect.get("type") for effect in card.get("effects", []) if isinstance(effect, dict)]
    if "damage" in kinds:
        return "攻击接触；再按牌义确定斩/刺/拳/法/丹、目标与落点"
    if "block" in kinds:
        return "护体/格挡；装备和身体受力须可读"
    if "heal" in kinds:
        return "自体回复；光应源于丹药/功法/施术动作"
    if "status" in kinds:
        return "状态施加；法印/毒/剑意按牌义分离"
    return "资源或抽牌；角色动作仍需逐牌分镜"


def build_card_workbook(data: dict, sha: str) -> str:
    cards = unique_rows(data["cards"]["battle_cards"], "battle card")
    action = data["actions"]
    direct = set(action.get("cardActions", {})) | set(action.get("cardEffectPresentations", {})) | set(action.get("semanticVfx", {}))
    lines = source_header("四专修战斗卡动作逐项制作台账", sha)
    lines += [
        f"来源战斗卡 {len(cards)} 张；已有同名独立动作/效果条目 {len(cards.keys() & direct)} 张。"
        "其余卡不能因为有四专修公共动作就宣称已得到专属动画。",
        "此表锁住每张卡的来源效果、动作节拍入口和缺口；独立接触姿态、FX、"
        "灯光、声音、受击与缩减动态版本仍须逐卡签收。", "",
        "| 卡 ID / 名称 | 专修 | 来源效果 | 原卡牌义 | 本卡动作节拍草案 | 现有同名条目 | 制作状态 |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for card_id, card in sorted(cards.items()):
        kinds = [str(effect.get("type", "")) for effect in card.get("effects", []) if isinstance(effect, dict)]
        refs = [kind for kind, catalog in (("cardAction", action.get("cardActions", {})),
                 ("effectPresentation", action.get("cardEffectPresentations", {})),
                 ("semanticVfx", action.get("semanticVfx", {}))) if card_id in catalog]
        image = card.get("cardArt", {}).get("image", "")
        art_note = "卡图存在" if image and (ROOT / image).is_file() else "卡图待核"
        lines.append("| " + " | ".join(map(cell, (
            f"{card_id} / {card.get('name', '')}", path_for(card), "+".join(kinds) or "无效果",
            card.get("flavor") or card.get("description", ""),
            combat_beat(card), "+".join(refs) or "仅公共流派路由",
            f"{art_note}；专属分镜未终验"))) + " |")
    lines += ["", "现有动作和 FX 的具体帧/时序仍以 `data/combat/action_presentations.json` 为准；"
              "此处的节拍是制作入口，不是画完的动画。", ""]
    return "\n".join(lines)


def build_equipment_workbook(data: dict, sha: str) -> str:
    treasures = unique_rows(data["treasures"]["treasures"], "treasure")
    lines = source_header("装备外观与挂点逐项制作台账", sha)
    lines += [
        f"来源法宝/装备 {len(treasures)} 件；装备槽：{', '.join(SLOTS)}。"
        "数值与归属仍由装备实例账本拥有，表中只处理战斗可见外观。", "",
        "| 定义 ID / 名称 | 槽位 / 境界 | 原物品特征 | 视觉承载与动作需求 | 来源战斗展示 | 战斗外观状态 |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    carrier = {
        "weapon": "按物品形制选手持/鞘/腰位；必要时逐帧剑尖与前后遮挡，不按槽位假定全是剑",
        "armor": "躯干/臂部受力层或同骨架外观变体；不可压盖手臂",
        "accessory": "腰/头/背挂点；近景可辨轮廓与局部材质",
        "artifact": "器物挂点或出牌时实例化；常驻与召唤状态分离",
    }
    for treasure_id, item in sorted(treasures.items()):
        slot = item.get("type", "")
        if slot not in SLOTS:
            raise ValueError(f"未知装备槽位：{treasure_id}:{slot}")
        combat = item.get("combatPresentation", {})
        cue = combat.get("id", "") if isinstance(combat, dict) else ""
        lines.append("| " + " | ".join(map(cell, (
            f"{treasure_id} / {item.get('name', '')}", f"{slot} / {item.get('realm', '')}",
            item.get("desc", ""), carrier[slot], cue or "无专属战斗展示",
            "未提供可换装角色资产；待制作/接线"))) + " |")
    lines += ["", "严禁从数值效果推断模型外形。每件的外观母版、可见部位、"
              "挂点轨迹、遮挡与战斗实机证据在装备专项任务书的契约下逐件补齐。", ""]
    return "\n".join(lines)


def build() -> dict[Path, str]:
    data = {name: read(path) for name, path in INPUTS.items()}
    if set(data["paths"].get("paths", {})) != set(PATH_IDS):
        raise ValueError("四专修来源 ID 与制作合同不一致")
    sha = fingerprint()
    return {
        OUT / "SCENE_ENEMY_INVENTORY.md": build_scene_workbook(data, sha),
        OUT / "CARD_ACTION_INVENTORY.md": build_card_workbook(data, sha),
        OUT / "EQUIPMENT_VISUAL_INVENTORY.md": build_equipment_workbook(data, sha),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Fail if any derived workbook is missing or stale")
    args = parser.parse_args()
    output = build()
    if args.check:
        stale = [str(path.relative_to(ROOT)) for path, text in output.items()
                 if not path.is_file() or path.read_text(encoding="utf-8") != text]
        if stale:
            raise SystemExit("BATTLE_PRODUCTION_WORKBOOK_STALE: " + ", ".join(stale))
    else:
        OUT.mkdir(parents=True, exist_ok=True)
        for path, content in output.items():
            path.write_text(content, encoding="utf-8")
    print(f"BATTLE_PRODUCTION_WORKBOOK_PASS files={len(output)}")


if __name__ == "__main__":
    main()
