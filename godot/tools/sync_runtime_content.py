"""Copy browser runtime JSON and referenced art verbatim into the Godot project.

The browser repository remains authoritative.  No card, encounter or save value
is authored by this script; the fixture is extracted from M0's real browser save.
"""

import hashlib
import json
import re
import shutil
import struct
from pathlib import Path

from PIL import Image


PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT.parent
CONTENT = PROJECT / "content"
SAVE_EVIDENCE = ROOT / "artifacts/godot-migration/m0-2026-10-15/slots-synthetic-raw.json"
TRACE_EVIDENCE = ROOT / "artifacts/godot-migration/m0-2026-10-15/battle-trace-desktop.json"
FULL_RNG_EVIDENCE = ROOT / "artifacts/godot-migration/source-first-fight/m0-full-battle-rng.json"
NONCOMBAT_TRACE_EVIDENCE = ROOT / "artifacts/godot-migration/noncombat-opening/browser-source-trace.json"
NONCOMBAT_PROLOGUE_EVIDENCE = ROOT / "artifacts/godot-migration/noncombat-opening/browser-prologue-trace.json"
ENCOUNTER_ID = "enc_trial_sword_swift"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def webp_frame_durations(source_bytes):
    """Read ANMF millisecond timing from the authored RIFF/WebP container."""
    if not (source_bytes.startswith(b"RIFF") and source_bytes[8:12] == b"WEBP"):
        raise ValueError("Not a WebP RIFF container")
    position = 12
    durations = []
    while position + 8 <= len(source_bytes):
        fourcc = source_bytes[position:position + 4]
        size = struct.unpack_from("<I", source_bytes, position + 4)[0]
        payload = position + 8
        if payload + size > len(source_bytes):
            raise ValueError("Truncated WebP chunk")
        if fourcc == b"ANMF":
            if size < 16:
                raise ValueError("Truncated WebP animation frame")
            duration = int.from_bytes(source_bytes[payload + 12:payload + 15], "little")
            if duration <= 0:
                raise ValueError("Ambiguous zero-duration WebP frame")
            durations.append(duration)
        position = payload + size + (size & 1)
    return durations


def copy_source(relative_path):
    source = ROOT / relative_path
    if not source.is_file():
        raise FileNotFoundError(source)
    target = CONTENT / relative_path
    target.parent.mkdir(parents=True, exist_ok=True)
    source_hash = sha256(source)
    if not target.is_file() or sha256(target) != source_hash:
        shutil.copyfile(source, target)
    if source_hash != sha256(target):
        raise RuntimeError(f"Copy changed bytes: {relative_path}")
    return {"path": relative_path.as_posix(), "sha256": source_hash, "bytes": source.stat().st_size}


data_files = sorted((ROOT / "data").rglob("*.json"))
data = [copy_source(path.relative_to(ROOT)) for path in data_files]
cards = json.loads((ROOT / "data/cards/battle_cards.json").read_text(encoding="utf-8"))
presentations = json.loads((ROOT / "data/combat/encounter_presentations.json").read_text(encoding="utf-8"))
paths = json.loads((ROOT / "data/combat/path_presentations.json").read_text(encoding="utf-8"))
actions = json.loads((ROOT / "data/combat/action_presentations.json").read_text(encoding="utf-8"))
encounter = presentations["presentations"][ENCOUNTER_ID]
art_paths = {encounter["sceneImage"], encounter["actorCards"]["enemy"]["image"],
             paths["paths"]["sword"]["actorCard"]["image"]}
first_deck = ("sword_probe", "sword_followthrough", "sword_guard", "sword_sheath_guard", "sword_edge")
by_id = {card["id"]: card for card in cards["battle_cards"]}
for card_id in first_deck:
    art_paths.add(by_id[card_id]["cardArt"]["image"])
for card_id in ("sword_probe", "sword_followthrough", "sword_sheath_guard", "sword_edge"):
    art_paths.update(actions["cardActions"][card_id]["animation"]["frames"])
for action in actions["paths"]["sword"].values():
    art_paths.update(action["animation"]["frames"])
for action in actions["encounters"][ENCOUNTER_ID].values():
    art_paths.update(action["animation"]["frames"])
for cue_id in ("sword_trace", "damage"):
    art_paths.update(actions["semanticVfx"][cue_id]["frames"])
art_paths.update(actions["semanticVfx"]["quick_sword_wood_contact"]["frames"])

# Mounted source S1 trials consume their own actor identity, cards and frames.
starter_decks = json.loads((ROOT / "data/combat/deck_progression.json").read_text(encoding="utf-8"))[
    "paths"]
for path_id, encounter_id in (("spell", "enc_trial_spell_seal"),
                              ("body", "enc_trial_body_iron"),
                              ("pill", "enc_trial_pill_poison")):
    presentation = presentations["presentations"][encounter_id]
    art_paths.add(presentation["actorCards"]["enemy"]["image"])
    art_paths.add(paths["paths"][path_id]["actorCard"]["image"])
    for card_id in starter_decks[path_id]["starterDeck"]:
        art_paths.add(by_id[card_id]["cardArt"]["image"])
    for action in actions["paths"][path_id].values():
        art_paths.update(action["animation"]["frames"])
        for card_id, variant in action.get("variantsBySourceId", {}).items():
            if card_id in starter_decks[path_id]["starterDeck"]:
                art_paths.update(variant["animation"]["frames"])
    for action in actions["encounters"][encounter_id].values():
        art_paths.update(action["animation"]["frames"])

# The authored mountain follow-up consumes the current qi reward card, the
# patrol actor, and its own action sequence for every starting path.
mountain_id = "enc_patrol_qi_mountain_shadow"
mountain_presentation = presentations["presentations"][mountain_id]
art_paths.add(mountain_presentation["actorCards"]["enemy"]["image"])
for action in actions["encounters"][mountain_id].values():
    art_paths.update(action["animation"]["frames"])
for path_id, rules in starter_decks.items():
    available_cards = set(rules["starterDeck"])
    available_cards.update(rules["rewardPoolByRealm"]["qi"])
    for card_id in available_cards:
        art_paths.add(by_id[card_id]["cardArt"]["image"])
    for action in actions["paths"][path_id].values():
        for card_id, variant in action.get("variantsBySourceId", {}).items():
            if card_id in available_cards:
                art_paths.update(variant["animation"]["frames"])

# The non-combat opening uses the same authored qi cards as the browser.  Keep
# its images in the source manifest instead of hand-maintaining a second art
# list in Godot.
qi_cards = json.loads((ROOT / "data/cards/qi.json").read_text(encoding="utf-8"))
opening_by_id = {card["id"]: card for card in qi_cards["cards"]}
path_config = json.loads((ROOT / "data/config/paths.json").read_text(encoding="utf-8"))
opening_ids = {f"tutorial_{number}" for number in range(1, 5)}
opening_ids.update(path["startCard"] for path in path_config["paths"].values())
for card_id in sorted(opening_ids):
    card = opening_by_id.get(card_id)
    if not card:
        raise ValueError(f"Missing authored opening card: {card_id}")
    image_path = card.get("sceneImage")
    if not isinstance(image_path, str) or not image_path.startswith("assets/cards/events/") \
            or ".." in Path(image_path).parts:
        raise ValueError(f"Invalid opening art path: {card_id}: {image_path!r}")
    art_paths.add(image_path)

# The encounter invitation is a non-combat decision screen. Its authored
# presentation image belongs in the opening package for every starting path,
# even when the source file lives below assets/combat/.
first_session = json.loads((ROOT / "data/progression/first_session_cohesion.json").read_text(encoding="utf-8"))
first_session_encounters = {route["teachingEncounterId"] for route in first_session["paths"].values()}
first_session_encounters.add(first_session["beats"]["route"]["encounterId"])
catalog = json.loads((ROOT / "data/combat/encounters.json").read_text(encoding="utf-8"))
first_session_encounters.update(row["id"] for row in catalog["encounters"]
    if row.get("realm") == "qi" and row.get("encounterRole") != "boss"
    and row.get("encounterKind") != "realm_boss")
for encounter_id in sorted(first_session_encounters):
    image_path = presentations["presentations"][encounter_id]["sceneImage"]
    if not isinstance(image_path, str) or not image_path.startswith("assets/") \
            or ".." in Path(image_path).parts:
        raise ValueError(f"Invalid first-session encounter image: {encounter_id}: {image_path!r}")
    art_paths.add(image_path)

# Other non-combat systems still consume their authored art by source path.
# Package only images reachable from live data or the browser's scene/UI maps;
# generated-but-unreferenced workspace images are outside this migration.
noncombat_art_paths = set()


def collect_noncombat_images(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "sceneImage" and isinstance(child, str) \
                    and child.startswith("assets/combat/") \
                    and Path(child).suffix.lower() in {".png", ".webp", ".jpg", ".jpeg"}:
                noncombat_art_paths.add(child)
            collect_noncombat_images(child)
    elif isinstance(value, list):
        for child in value:
            collect_noncombat_images(child)
    elif isinstance(value, str) and value.startswith("assets/") \
            and not value.startswith("assets/combat/") \
            and Path(value).suffix.lower() in {".png", ".webp", ".jpg", ".jpeg"}:
        noncombat_art_paths.add(value)


for source in (ROOT / "data").rglob("*.json"):
    if "combat" not in source.relative_to(ROOT / "data").parts:
        collect_noncombat_images(json.loads(source.read_text(encoding="utf-8")))
# Scan the browser's authored source graph and entrypoint surfaces.  The
# PC98CardSystem installs portraits at runtime, while HTML/CSS own icons and
# backgrounds that do not appear in JSON card records.
entrypoint = (ROOT / "index.html").read_text(encoding="utf-8")
loaded_styles = set(re.findall(
    r'<link\b[^>]*\bhref=["\'](styles/[^"\']+\.css)["\']', entrypoint
))
if not loaded_styles:
    raise ValueError("Browser entrypoint has no linked styles")
static_sources = [ROOT / "index.html", *(ROOT / "src").rglob("*.js")]
static_sources.extend(ROOT / relative for relative in sorted(loaded_styles))
media_manifest_source = ROOT / "assets/card-illustrations/manifest.js"
if "assets/card-illustrations/manifest.js" not in (ROOT / "src/ui/NarrativeCardExhibit.js").read_text(encoding="utf-8"):
    raise ValueError("Narrative media manifest is no longer loaded by the browser")
static_sources.append(media_manifest_source)
for source in static_sources:
    content = source.read_text(encoding="utf-8")
    noncombat_art_paths.update(path for path in re.findall(
        r"assets/[A-Za-z0-9_./-]+\.(?:png|webp|jpe?g)", content
    ) if not path.startswith("assets/combat/"))
for image_path in noncombat_art_paths:
    image_relative = Path(image_path)
    if image_relative.is_absolute() or ".." in image_relative.parts or not (ROOT / image_relative).is_file():
        raise ValueError(f"Missing or unsafe authored non-combat image: {image_path}")
# LitPixelRenderer constructs base, normal and material source paths from an
# NPC ID at runtime. The source directory is the authored set of available
# triplets; the independent validator checks it against GameUI's ID map.
for base in (ROOT / "assets/characters").glob("concept_*.webp"):
    for suffix in (".webp", "_normal.png", "_material.png"):
        relative = Path("assets/characters") / (base.stem + suffix)
        if not (ROOT / relative).is_file():
            raise ValueError(f"Incomplete LitPixel character triplet: {relative}")
        noncombat_art_paths.add(relative.as_posix())
art_paths.update(noncombat_art_paths)
# Migrated inline battles use presentation art stored in combat data, so the
# general noncombat scan skips these source paths.
migrated = json.loads((ROOT / "data/combat/migrated_presentations.json").read_text(encoding="utf-8"))


def collect_thread_battle_art(value):
    if isinstance(value, dict):
        for child in value.values():
            collect_thread_battle_art(child)
    elif isinstance(value, list):
        for child in value:
            collect_thread_battle_art(child)
    elif isinstance(value, str) and value.startswith("assets/") \
            and Path(value).suffix.lower() in {".png", ".webp", ".jpg", ".jpeg"}:
        art_paths.add(value)


for presentation_key in ("q_fellow:right", "f_mission:right", "thread_ab_village_3:left",
                         "thread_ab_village_3:right", "thread_sword_tomb_2:left",
                         "thread_sword_tomb_2:right", "n_hunt:left", "ar_boss:left",
                         "it_combat:left"):
    collect_thread_battle_art(migrated["presentations"][presentation_key])
boss_actions = json.loads((ROOT / "data/combat/action_presentations.json").read_text(encoding="utf-8"))
collect_thread_battle_art(boss_actions["bossPhaseTransitions"]["realm_guardian"])
chapters = json.loads((ROOT / "data/cards/chapter_milestones.json").read_text(encoding="utf-8"))
collect_thread_battle_art(chapters["ch_qi_100"]["combatPresentation"])
for action in actions["encounters"]["enc_boss_qi_thunder_gate"].values():
    collect_thread_battle_art(action)
collect_thread_battle_art(chapters["ch_foundation_100"]["combatPresentation"])
collect_thread_battle_art(chapters["ch_golden_100"]["combatPresentation"])
collect_thread_battle_art(chapters["ch_nascent_100"]["combatPresentation"])
collect_thread_battle_art(chapters["ch_deity_100"]["combatPresentation"])
collect_thread_battle_art(chapters["ch_tribulation_100"]["combatPresentation"])
bandit_cards = json.loads((ROOT / "data/cards/demonic_seductress.json").read_text(encoding="utf-8"))["cards"]
bandit = next(card for card in bandit_cards if card["id"] == "ds_female_bandit")
collect_thread_battle_art(bandit["choices"]["left"])
for cadence_encounter in catalog["encounters"]:
    if cadence_encounter.get("realm") in {
            "foundation", "golden", "nascent", "deity", "tribulation"} \
            and cadence_encounter.get("category") != "realmBoss":
        collect_thread_battle_art(cadence_encounter)
        collect_thread_battle_art(presentations["presentations"][cadence_encounter["id"]])
# This faction invitation now mounts the authored multi-frame enemy actions
# in a production Godot stage. Keep every consumed frame in the source manifest.
for action in actions["encounters"]["enc_faction_wumeng_elite"].values():
    collect_thread_battle_art(action)
old_master = next(row for row in catalog["encounters"]
                  if row["id"] == "enc_companion_jian_linger_tomb")
collect_thread_battle_art(old_master)
for action in actions["encounters"][old_master["id"]].values():
    collect_thread_battle_art(action)
# The reachable white-fox fight is authored on the quest choice itself, not
# in the catalog encounter/presentation tables.
whitefox = json.loads((ROOT / "data/quests/white_fox.json").read_text(encoding="utf-8"))
whitefox_third = next(card for card in whitefox["cards"] if card["id"] == "q_whiteFox_3")
collect_thread_battle_art(whitefox_third["choices"]["left"]["combatPresentation"])
last_lesson = json.loads((ROOT / "data/threads/last_lesson_threads.json").read_text(encoding="utf-8"))
for thread in last_lesson["threads"]:
    for node in thread.get("nodes", []):
        for choice in node.get("card", {}).get("choices", {}).values():
            presentation = choice.get("combatPresentation", {})
            collect_thread_battle_art(presentation)
            assist_id = presentation.get("storyAssist", {}).get("cardId")
            if assist_id:
                art_paths.add(by_id[assist_id]["cardArt"]["image"])
# Browsers sniff image bytes. Godot imports by extension.  Preserve mislabeled
# JPEG bytes under truthful .jpg aliases and let the runtime registry translate
# the browser's authored path; never feed a JPEG to the PNG importer.
runtime_aliases = []
animated_media = []
for source_path in sorted(art_paths):
    source_file = ROOT / source_path
    magic = source_file.read_bytes()[:12]
    suffix = Path(source_path).suffix.lower()
    if suffix == ".webp" and magic.startswith(b"RIFF") and magic[8:12] == b"WEBP":
        with Image.open(source_file) as source_animation:
            if source_animation.n_frames > 1:
                durations = webp_frame_durations(source_file.read_bytes())
                if len(durations) != source_animation.n_frames:
                    raise ValueError(f"Animated WebP frame timing mismatch: {source_path}")
                archive_relative = Path("source_media") / Path(source_path).with_suffix(".webp.bin")
                archive_target = CONTENT / archive_relative
                archive_target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source_file, archive_target)
                if sha256(source_file) != sha256(archive_target):
                    raise RuntimeError(f"Animated WebP archive changed source bytes: {source_path}")
                frames = []
                frame_directory = Path("media_frames") / Path(source_path).with_suffix("")
                for index, duration in enumerate(durations):
                    source_animation.seek(index)
                    frame = source_animation.convert("RGBA")
                    relative = frame_directory / f"frame-{index:03d}.png"
                    target = CONTENT / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    frame.save(target, format="PNG")
                    frames.append({"path": relative.as_posix(), "sha256": sha256(target),
                                   "durationMs": duration, "width": frame.width, "height": frame.height})
                animated_media.append({"sourcePath": source_path,
                                       "sourceSha256": sha256(source_file),
                                       "archivePath": archive_relative.as_posix(),
                                       "archiveSha256": sha256(archive_target),
                                       "frames": frames})
                # A previous sync may have copied this animated file under its
                # original extension; Godot's image importer cannot decode it.
                old_copy = CONTENT / source_path
                if old_copy.is_file():
                    old_copy.unlink()
                old_sidecar = CONTENT / (source_path + ".import")
                if old_sidecar.is_file():
                    old_sidecar.unlink()
                continue
    if suffix == ".png" and magic.startswith(b"\xff\xd8\xff"):
        runtime_path = str(Path(source_path).with_suffix(".jpg")).replace("\\", "/")
        target = CONTENT / runtime_path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source_file, target)
        if sha256(source_file) != sha256(target):
            raise RuntimeError(f"JPEG alias changed source bytes: {source_path}")
        runtime_aliases.append({
            "sourcePath": source_path,
            "runtimePath": runtime_path,
            "sha256": sha256(source_file),
            "bytes": source_file.stat().st_size,
            "reason": "source .png contains JPEG bytes; Godot requires matching import extension",
        })
    elif suffix == ".png" and not magic.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Unsupported PNG source magic: {source_path}")
    elif suffix in {".jpg", ".jpeg"} and not magic.startswith(b"\xff\xd8\xff"):
        raise ValueError(f"Unsupported JPEG source magic: {source_path}")
    elif suffix == ".webp" and not (magic.startswith(b"RIFF") and magic[8:12] == b"WEBP"):
        raise ValueError(f"Unsupported WebP source magic: {source_path}")
alias_sources = {item["sourcePath"] for item in runtime_aliases}
animated_sources = {item["sourcePath"] for item in animated_media}
art = [copy_source(Path(path)) for path in sorted(art_paths - alias_sources - animated_sources)]

media_assignment = media_manifest_source.read_text(encoding="utf-8").partition("NarrativeCardExhibit.media=")
if not media_assignment[1]:
    raise ValueError("Narrative media manifest assignment changed")
media_registry = json.loads(media_assignment[2].strip().removesuffix(";"))
media_target = CONTENT / "data/media/narrative_card_media.json"
media_target.parent.mkdir(parents=True, exist_ok=True)
media_target.write_text(json.dumps(media_registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

audio_config = json.loads((ROOT / "data/audio/path_identity.json").read_text(encoding="utf-8"))
if audio_config.get("assetRoot") != "assets/audio/":
    raise ValueError("Authored audio root changed")
audio_paths = set()


def collect_runtime_audio(value):
    if isinstance(value, dict):
        runtime = value.get("runtime")
        if isinstance(runtime, dict) and isinstance(runtime.get("path"), str):
            relative = Path(audio_config["assetRoot"]) / runtime["path"]
            if (relative.is_absolute() or ".." in relative.parts
                    or relative.suffix.lower() not in {".mp3", ".wav", ".ogg"}):
                raise ValueError(f"Unsafe authored audio path: {relative}")
            audio_paths.add(relative.as_posix())
        for child in value.values():
            collect_runtime_audio(child)
    elif isinstance(value, list):
        for child in value:
            collect_runtime_audio(child)


collect_runtime_audio(audio_config)
audio = [copy_source(Path(relative)) for relative in sorted(audio_paths)]

raw_saves = json.loads(SAVE_EVIDENCE.read_text(encoding="utf-8"))
slot = json.loads(raw_saves["xiuxian_unlocks_slot_3"])
session = slot["causalSessionState"]["combatSession"]
if session["version"] != 3 or not session["active"] or session["enemy"]["def"]["id"] != "trial_aggressor_qi":
    raise ValueError("M0 fixture is not the active first-fight snapshot")
fixture_dir = CONTENT / "fixtures"
fixture_dir.mkdir(exist_ok=True)
noncombat_trace = json.loads(NONCOMBAT_TRACE_EVIDENCE.read_text(encoding="utf-8"))
if [step.get("currentCardId") for step in noncombat_trace.get("trace", [])] != [
    "tutorial_1", "tutorial_4", "q_start_sword"
]:
    raise ValueError("Live browser opening trace does not match its authored branch")
required_opening_sources = {
    "index.html", "src/game.js", "src/ui.js", "src/core/GameStateManager.js",
    "src/services/EffectService.js", "data/cards/qi.json",
    "data/config/paths.json", "data/config/realms.json",
}
source_hashes = noncombat_trace.get("sourceHashes", {})
if not required_opening_sources.issubset(source_hashes) or source_hashes != noncombat_trace.get("servedSourceHashes"):
    raise ValueError("Browser opening trace lacks matching served source provenance")
for relative_path, source_hash in source_hashes.items():
    source_relative = Path(relative_path)
    if (".." in source_relative.parts or source_relative.is_absolute()
            or (relative_path not in required_opening_sources
                and not relative_path.startswith("src/"))
            or sha256(ROOT / relative_path) != source_hash):
        raise ValueError(f"Browser opening trace is stale: {relative_path}")
noncombat_fixture = fixture_dir / "noncombat_opening_source_trace.json"
shutil.copyfile(NONCOMBAT_TRACE_EVIDENCE, noncombat_fixture)
if sha256(noncombat_fixture) != sha256(NONCOMBAT_TRACE_EVIDENCE):
    raise RuntimeError("Browser opening trace copy changed bytes")
prologue_trace = json.loads(NONCOMBAT_PROLOGUE_EVIDENCE.read_text(encoding="utf-8"))
expected_cases = {(path, direction) for path in ("sword", "spell", "body", "pill")
                  for direction in ("left", "right")}
if prologue_trace.get("tutorialDirections") != ["right", "left"] or {
    (case.get("path"), case.get("direction")) for case in prologue_trace.get("cases", [])
} != expected_cases or len(prologue_trace.get("cases", [])) != 8:
    raise ValueError("Live browser prologue trace does not cover eight authored decisions")
required_prologue_sources = {
    "index.html", "src/game.js", "src/core/GameStateManager.js",
    "src/services/EffectService.js", "src/systems/KarmaSystem.js",
    "src/systems/RealmChapterSystem.js", "src/systems/CardSystem.js",
    "src/systems/EncounterDirector.js", "src/systems/FlowDirector.js",
    "data/cards/qi.json", "data/config/paths.json",
    "data/cards/chapter_milestones.json",
    "data/progression/first_session_cohesion.json", "data/combat/encounters.json",
}
if not required_prologue_sources.issubset(prologue_trace.get("sourceHashes", {})):
    raise ValueError("Browser prologue trace misses route-authority source hashes")
for relative_path, expected_hash in prologue_trace.get("sourceHashes", {}).items():
    if (Path(relative_path).is_absolute() or ".." in Path(relative_path).parts
            or not (ROOT / relative_path).is_file()
            or sha256(ROOT / relative_path) != expected_hash):
        raise ValueError(f"Browser prologue trace is stale: {relative_path}")
prologue_fixture = fixture_dir / "noncombat_prologue_source_trace.json"
shutil.copyfile(NONCOMBAT_PROLOGUE_EVIDENCE, prologue_fixture)
if sha256(prologue_fixture) != sha256(NONCOMBAT_PROLOGUE_EVIDENCE):
    raise RuntimeError("Browser prologue trace copy changed bytes")
(fixture_dir / "m0_slot3_combat_session.json").write_text(
    json.dumps(session, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
trace = json.loads(TRACE_EVIDENCE.read_text(encoding="utf-8"))
opening = trace["trace"][5]["battle"]
assert opening["phase"] == "PLAYER_TURN" and opening["enemy"]["hp"] == 7
opening_fixture = {
    "sourceStep": 5, "sourceSeed": trace["seed"],
    "phase": opening["phase"], "turn": opening["turn"], "qi": opening["qi"],
    "player": opening["player"], "enemy": opening["enemy"],
    "hand": [item["id"] for item in opening["hand"]],
    "masterDeck": session["masterDeck"],
    "enemyIntent": session["enemyIntent"],
}
(fixture_dir / "m0_desktop_opening.json").write_text(
    json.dumps(opening_fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
first_turn_expected = []
for trace_step in trace["trace"][5:11]:
    battle = trace_step["battle"]
    first_turn_expected.append({
        "step": trace_step["step"], "phase": battle["phase"], "turn": battle["turn"],
        "qi": battle["qi"], "playerHp": battle["player"]["hp"],
        "playerBlock": battle["player"]["block"], "enemyHp": battle["enemy"]["hp"],
        "enemyBlock": battle["enemy"]["block"],
        "planState": battle["enemy"]["planRuntime"]["currentState"],
        "hand": [item["id"] for item in battle["hand"]],
    })
(fixture_dir / "m0_first_turn_expected.json").write_text(
    json.dumps({"source": str(TRACE_EVIDENCE.relative_to(ROOT)).replace("\\", "/"),
                "steps": first_turn_expected}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
full_rng = json.loads(FULL_RNG_EVIDENCE.read_text(encoding="utf-8"))
if full_rng["seed"] != trace["seed"] or full_rng["pageErrors"] or \
        full_rng["steps"][-1]["cardId"] != "combat_reward":
    raise ValueError("Live source replay did not reach the original first-fight reward")
full_steps = [step for step in full_rng["steps"] if step["phase"]]
frozen_steps = [step for step in trace["trace"] if isinstance(step.get("step"), int)
                and 5 <= step["step"] <= 16]
if len(full_steps) != 12 or len(frozen_steps) != 12:
    raise ValueError("First-fight trace must contain source steps 5 through 16")
for current, frozen in zip(full_steps, frozen_steps):
    battle = frozen["battle"]
    authoritative = {
        "phase": battle["phase"], "turn": battle["turn"], "qi": battle["qi"],
        "playerHp": battle["player"]["hp"], "playerBlock": battle["player"]["block"],
        "enemyHp": battle["enemy"]["hp"], "enemyBlock": battle["enemy"]["block"],
        "planState": battle["enemy"]["planRuntime"]["currentState"],
        "hand": [card["id"] for card in battle["hand"]],
    }
    if current["step"] != frozen["step"] or any(
            current[key] != value for key, value in authoritative.items()):
        raise ValueError(f"Current browser combat drifted from frozen M0 at step {frozen['step']}")
    source_action = frozen.get("combatAction", {})
    expected_action = (source_action.get("playCard") or source_action.get("reaction")
                       or ("END_TURN" if source_action.get("endTurn") else ""))
    if current["action"] != expected_action:
        raise ValueError(f"Browser action drifted at step {frozen['step']}")
random_tape = full_rng["randomTape"]
if len(random_tape) != 9 or any("DeckCombatSystem._" not in item["caller"]
                                for item in random_tape):
    raise ValueError("The captured random tape contains missing or non-combat callers")
full_fixture = {
    "source": str(FULL_RNG_EVIDENCE.relative_to(ROOT)).replace("\\", "/"),
    "frozenTrace": str(TRACE_EVIDENCE.relative_to(ROOT)).replace("\\", "/"),
    "randomValues": [item["value"] for item in random_tape],
    "steps": [{key: step[key] for key in (
        "step", "action", "phase", "turn", "qi", "playerHp", "playerBlock",
        "enemyHp", "enemyBlock", "planState", "enemyIntent", "pathCombatState",
        "playerStatus", "enemyStatus", "hand", "drawPile", "discardPile")}
              for step in full_steps],
    "sourceRewardCardId": full_rng["steps"][-1]["cardId"],
    "sourceRewardPathCombatState": full_rng["steps"][-1]["pathCombatState"],
}
(fixture_dir / "m0_full_battle_expected.json").write_text(
    json.dumps(full_fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
manifest = {
    "schema": 1,
    "source": "current browser working tree",
    "data": data,
    "art": art,
    "audio": audio,
    "runtimeAliases": runtime_aliases,
    "animatedMedia": animated_media,
    "narrativeMedia": {
        "source": "assets/card-illustrations/manifest.js",
        "sourceSha256": sha256(media_manifest_source),
        "runtimeJson": "data/media/narrative_card_media.json",
        "runtimeSha256": sha256(media_target),
    },
    "noncombatOpeningTrace": {
        "source": str(NONCOMBAT_TRACE_EVIDENCE.relative_to(ROOT)).replace("\\", "/"),
        "sourceSha256": sha256(NONCOMBAT_TRACE_EVIDENCE),
        "fixture": "content/fixtures/noncombat_opening_source_trace.json",
    },
    "noncombatPrologueTrace": {
        "source": str(NONCOMBAT_PROLOGUE_EVIDENCE.relative_to(ROOT)).replace("\\", "/"),
        "sourceSha256": sha256(NONCOMBAT_PROLOGUE_EVIDENCE),
        "fixture": "content/fixtures/noncombat_prologue_source_trace.json",
    },
    "fixture": {"source": str(SAVE_EVIDENCE.relative_to(ROOT)).replace("\\", "/"),
                "sourceSha256": sha256(SAVE_EVIDENCE), "saveVersion": slot["saveVersion"],
                "combatVersion": session["version"], "encounterId": ENCOUNTER_ID,
                "openingTraceSource": str(TRACE_EVIDENCE.relative_to(ROOT)).replace("\\", "/"),
                "openingTraceSha256": sha256(TRACE_EVIDENCE),
                "fullRngSource": str(FULL_RNG_EVIDENCE.relative_to(ROOT)).replace("\\", "/"),
                "fullRngSourceSha256": sha256(FULL_RNG_EVIDENCE)},
}
(CONTENT / "source_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"RUNTIME_CONTENT_SYNCED data={len(data)} art={len(art)} noncombat_art={len(noncombat_art_paths)} audio={len(audio)} saveSchema={slot['saveVersion']} combatSchema={session['version']}")
