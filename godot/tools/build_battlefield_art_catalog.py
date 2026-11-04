"""Freeze source presentation identities into a Godot art-production ledger.

This script inventories content; it does not manufacture finished scenes.
"""

from __future__ import annotations

import json
import argparse
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "godot" / "art_direction" / "battlefield_art_catalog.json"
FIRST = "battlefield_enc_trial_sword_swift_native_v1"
VILLAGE_WELL = "battlefield_thread_ab_village_3_left_native_v1"
VILLAGE_WELL_CANDIDATE = "res://scenes/village_well_chamber_candidate.tscn"

FAMILIES = {
    "archetypeTrial": "cultivation_trial",
    "realmBoss": "realm_gate_boss",
    "factionElite": "faction_identity",
    "companionQuest": "companion_story_location",
    "heavenChaos": "heaven_chaos_finale",
    "realmPatrol": "route_wilderness",
    "realmQuotaOrdinary": "route_wilderness",
    "realmQuest": "realm_story_objective",
    "realmElite": "realm_story_objective",
}

MIGRATED_FAMILIES = {
    "f_mission:right": "beast_lair",
    "n_hunt:left": "corrupted_hunting_ground",
    "ar_boss:left": "imperial_mausoleum",
    "q_fellow:right": "qingyun_sparring_terrace",
    "it_combat:left": "immortal_rift",
    "thread_ab_village_3:left": "village_well_chamber",
    "thread_ab_village_3:right": "village_well_chamber",
    "thread_sword_tomb_2:left": "sword_tomb",
    "thread_sword_tomb_2:right": "sword_tomb",
    "thread_last_lesson_n3:left": "market_stone_street_provisional",
}


def read(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def build() -> dict:
    encounters = {row["id"]: row for row in read("data/combat/encounters.json")["encounters"]}
    overrides = read("godot/art_direction/battlefield_design_overrides.json")
    catalogs = [
        ("encounter", read("data/combat/encounter_presentations.json")["presentations"]),
        ("migrated_choice", read("data/combat/migrated_presentations.json")["presentations"]),
    ]
    grouped: dict[str, list[dict]] = defaultdict(list)
    for source_kind, source in catalogs:
        for source_key, presentation in source.items():
            battlefield_id = presentation["battlefieldId"]
            source_image = presentation["sceneImage"]
            if not (ROOT / source_image).is_file():
                raise ValueError(f"Missing source battlefield image: {source_image}")
            encounter = encounters.get(source_key, {}) if source_kind == "encounter" else {}
            category = encounter.get("category", "migrated_choice")
            family = FAMILIES.get(category) if encounter else MIGRATED_FAMILIES.get(source_key)
            if family is None:
                raise ValueError(f"Unclassified presentation: {source_key}")
            grouped[battlefield_id].append({
                "sourceKind": source_kind,
                "sourceKey": source_key,
                "presentationId": presentation["presentationId"],
                "sceneImage": source_image,
                "title": presentation.get("warningTitle", encounter.get("title", "")),
                "mechanic": presentation.get("mechanic", encounter.get("mechanic", "")),
                "category": category,
                "realm": encounter.get("realm", ""),
                "productionFamily": family,
                "enemyScaleProfileId": presentation.get("actorCards", {}).get("enemy", {}).get("scaleProfileId", ""),
            })
    entries: dict[str, dict] = {}
    for battlefield_id, sources in sorted(grouped.items()):
        families = {source["productionFamily"] for source in sources}
        if len(families) != 1:
            raise ValueError(f"Conflicting art families for {battlefield_id}: {families}")
        is_first = battlefield_id == FIRST
        is_village_well = battlefield_id == VILLAGE_WELL
        entries[battlefield_id] = {
            "battlefieldId": battlefield_id,
            "productionFamily": next(iter(families)),
            "sources": sources,
            "artStatus": "candidate_visual_fail" if is_first else "unbuilt",
            "approvedForFinalArt": False,
            "runtimeScene": "res://assets/hd2d/world_v17/qingyun_tutorial_hall_v17.glb" if is_first else "",
            "candidateScene": "res://assets/hd2d/world_v6/cangmang_trial_hall_v6.glb" if is_first else (VILLAGE_WELL_CANDIDATE if is_village_well else ""),
            "candidateScenes": {
                "outdoor_v3": "res://assets/hd2d/world_v3/cangmang_outdoor_court_v3.glb",
                "trial_v4": "res://assets/hd2d/world_v4/cangmang_trial_court_v4.glb",
                "trial_v5": "res://assets/hd2d/world_v5/cangmang_trial_court_v5.glb",
                "trial_v6": "res://assets/hd2d/world_v6/cangmang_trial_hall_v6.glb",
                "trial_v7": "res://assets/hd2d/world_v7/qingyun_trial_hall_v7.glb",
                "trial_v8": "res://assets/hd2d/world_v5/cangmang_trial_court_v5.glb",
                "trial_v9": "res://assets/hd2d/world_v9/cangmang_trial_hall_v9.glb",
                "trial_v10": "res://assets/hd2d/world_v10/cangmang_trial_hall_v10.glb",
                "trial_v11": "res://assets/hd2d/world_v11/cangmang_trial_hall_v11.glb",
                "trial_v13": "res://assets/hd2d/world_v6/cangmang_trial_hall_v6.glb",
                "trial_v14": "res://assets/hd2d/world_v14/cangmang_trial_hall_v14.glb",
                "trial_v15": "res://assets/hd2d/world_v15/cangmang_trial_hall_v15.glb",
                "trial_v16": "res://assets/hd2d/world_v16/cangmang_trial_hall_v16.glb",
                "trial_v17": "res://assets/hd2d/world_v17/qingyun_tutorial_hall_v17.glb",
            } if is_first else ({"village_well_v1": VILLAGE_WELL_CANDIDATE} if is_village_well else {}),
            "stageProfile": {
                "playerActorScene": "res://scenes/yelingyun_s1_hd2d.tscn",
                "enemyActorScene": "res://scenes/quick_sword_dummy_hd2d.tscn",
                "playerHome": [-2.3, 0.0, 0.15],
                "enemyHome": [2.3, 0.0, -0.25],
                "cameraTarget": [0.0, 1.25, -0.72],
                "cameraHome": [0.0, 4.15, 10.7],
                "lightingProfile": "qingyun_first_fight",
                "contactFxProfile": "s1_source_timed_sword_wood",
            } if is_first else {},
            "reviewEvidence": "res://art_direction/FIRST_FIGHT_TECH_ART_WORKFLOW_20261018.md" if is_first else "",
        }
    if len(grouped) != 63 or sum(map(len, grouped.values())) != 64:
        raise ValueError("Expected 63 unique battlefield IDs from 64 presentation rows")
    duplicates = {key: rows for key, rows in grouped.items() if len(rows) > 1}
    if set(duplicates) != {"battlefield_thread_sword_tomb_2_native_v1"}:
        raise ValueError(f"Unexpected shared battlefield IDs: {sorted(duplicates)}")
    if not set(overrides).issubset(entries):
        raise ValueError(f"Design brief has unknown battlefield IDs: {sorted(set(overrides) - set(entries))}")
    for key, entry in entries.items():
        entry["designBrief"] = overrides.get(key, {"status": "pending_authored_brief"})
        baseline = entry["designBrief"].get("visualTechnicalBaseline", "")
        if baseline and not (ROOT / baseline).is_file():
            raise ValueError(f"Visual baseline screenshot missing for {key}: {baseline}")
        review = entry["reviewEvidence"]
        if review and not (ROOT / "godot" / review.removeprefix("res://")).is_file():
            raise ValueError(f"Review evidence missing for {key}: {review}")
        for scene in [entry["runtimeScene"], *entry["candidateScenes"].values(),
                      *[entry["stageProfile"].get(name, "") for name in
                        ("playerActorScene", "enemyActorScene")]]:
            if scene and not (ROOT / "godot" / scene.removeprefix("res://")).is_file():
                raise ValueError(f"Scene asset declared but missing: {scene}")
    return {
        "version": 1,
        "sourceOfTruth": [
            "data/combat/encounter_presentations.json",
            "data/combat/migrated_presentations.json",
        ],
        "policy": "Identity ledger, not art approval; no generic stage fallback",
        "presentationCount": 64,
        "battlefieldCount": 63,
        "battlefields": entries,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Fail if the committed ledger is stale")
    args = parser.parse_args()
    catalog = build()
    encoded = json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_text(encoding="utf-8") != encoded:
            raise SystemExit("BATTLEFIELD_ART_CATALOG_STALE: regenerate from source presentations")
        print("BATTLEFIELD_ART_CATALOG_CURRENT presentations=64 battlefields=63")
        return
    OUTPUT.write_text(encoded, encoding="utf-8")
    print(f"BATTLEFIELD_ART_CATALOG_BUILT presentations={catalog['presentationCount']} "
          f"battlefields={catalog['battlefieldCount']} output={OUTPUT}")


if __name__ == "__main__":
    main()
