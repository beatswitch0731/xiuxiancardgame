"""Exercise the real Godot 32-frame importer with distinct and repeated fixtures.

These flat rectangles are disposable test data, never candidate game art.
"""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "godot"
FIXTURE_PARENT = GODOT / "assets" / "actor_candidates"
ENGINE = ROOT / ".godot-toolchain" / "godot-4.7.2" / "Godot_v4.7.2-stable_win64_console.exe"


def build_fixture(directory: Path, distinct: bool, clip: str = "idle", sparse: bool = False) -> Path:
    width, height = (256, 320) if clip == "idle" else (512, 320)
    atlas = Image.new("RGBA", (width * 8, height * 4))
    frames = []
    for index in range(32):
        frame = Image.new("RGBA", (width, height))
        draw = ImageDraw.Draw(frame)
        draw.rectangle((width // 2 - 23, 90, width // 2 + 23, 280), fill=(40, 65, 83, 255))
        offset = index if distinct else 0
        x_detail = width // 2 - 19 + offset
        if sparse:
            draw.point((x_detail, 125), fill=(175, 183, 190, 255))
        else:
            draw.line((x_detail, 125, x_detail, 145), fill=(175, 183, 190, 255))
        x = (index % 8) * width
        y = (index // 8) * height
        atlas.paste(frame, (x, y))
        frames.append({"i": index, "x": x, "y": y, "w": width, "h": height,
                       "t": index / 16})
    stem = f"{clip}_{'sparse' if sparse else ('distinct' if distinct else 'repeated')}"
    sheet = directory / f"{stem}.png"
    atlas.save(sheet)
    index_path = directory / f"{stem}.json"
    index_path.write_text(
        json.dumps({"version": "1.0", "frame_size": {"w": width, "h": height},
                    "sheet_size": {"w": width * 8, "h": height * 4}, "frames": frames}),
        encoding="utf-8",
    )

    def res(path: Path) -> str:
        return "res://" + path.relative_to(GODOT).as_posix()

    manifest = {
        "actor": "yelingyun_s1", "clip": clip,
        "art_set_id": "fixture_yelingyun_s1", "visual_world_id": "cangmang_sect_pc98_v1",
        "logical_pixel_grid": 2,
        "sheet": res(sheet), "index": res(index_path),
        "output": res(directory / f"{clip}_candidate.tres"),
        "canvas": {"w": width, "h": height}, "duration_ms": 2000 if clip == "idle" else 526,
        "foot_y": 0.9625, "scale": 1.0,
    }
    if clip == "sword_probe":
        manifest.update({
            "feet_y": [0.9625] * 32,
            "blade_tips": [[width - 25, 120] for _ in range(32)],
            "contact_at_ms": 235,
            "contact_frame": 14,
        })
    manifest_path = directory / f"{stem}_manifest.json"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    return manifest_path


def validate(manifest: Path, validate_only: bool = True) -> subprocess.CompletedProcess[str]:
    res_path = "res://" + manifest.relative_to(GODOT).as_posix()
    args = [str(ENGINE), "--headless", "--path", str(GODOT),
            "--script", "res://tools/build_reviewed_actor_sequence.gd",
            "--", f"--manifest={res_path}"]
    if validate_only:
        args.append("--validate-only")
    return subprocess.run(
        args,
        capture_output=True, text=True, encoding="utf-8", errors="replace", check=False,
    )


def main() -> None:
    FIXTURE_PARENT.mkdir(parents=True, exist_ok=True)
    fixture = Path(tempfile.mkdtemp(prefix="_frame32_validation_", dir=FIXTURE_PARENT)).resolve()
    if not fixture.is_relative_to(GODOT.resolve()):
        raise RuntimeError(f"Unsafe fixture location: {fixture}")
    try:
        distinct_manifest = build_fixture(fixture, True)
        accepted = validate(distinct_manifest)
        rejected = validate(build_fixture(fixture, False))
        sparse_edits = validate(build_fixture(fixture, True, sparse=True))
        sword_manifest = build_fixture(fixture, True, "sword_probe")
        wide_action = validate(sword_manifest)
        print(accepted.stdout, accepted.stderr)
        print(rejected.stdout, rejected.stderr)
        print(sparse_edits.stdout, sparse_edits.stderr)
        print(wide_action.stdout, wide_action.stderr)
        if accepted.returncode != 0 or "REVIEWED_SEQUENCE_VALIDATED" not in accepted.stdout:
            raise AssertionError("32 distinct source cells were not accepted")
        if rejected.returncode == 0 or "Only 1 distinct" not in rejected.stderr:
            raise AssertionError("32 duplicate cells were not rejected")
        if sparse_edits.returncode == 0 or "meaningful frame transitions" not in sparse_edits.stderr:
            raise AssertionError("Single-pixel changes were misclassified as authored motion")
        if wide_action.returncode != 0 or "REVIEWED_SEQUENCE_VALIDATED" not in wide_action.stdout:
            raise AssertionError("512x320 action frames were not accepted")
        imported = subprocess.run(
            [str(ENGINE), "--headless", "--editor", "--import", "--path", str(GODOT)],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
            check=False, timeout=120,
        )
        if imported.returncode != 0:
            print(imported.stdout, imported.stderr)
            raise AssertionError("Godot did not import the temporary FrameRonin atlas")
        saved = validate(distinct_manifest, validate_only=False)
        saved_wide = validate(sword_manifest, validate_only=False)
        print(saved.stdout, saved.stderr)
        print(saved_wide.stdout, saved_wide.stderr)
        if saved.returncode != 0 or not (fixture / "idle_candidate.tres").is_file():
            raise AssertionError("Validated 32-frame atlas did not save a candidate SpriteFrames resource")
        if saved_wide.returncode != 0 or not (fixture / "sword_probe_candidate.tres").is_file():
            raise AssertionError("Validated 512x320 action atlas did not save a candidate resource")
        for clip in ("idle", "sword_probe"):
            resource = "res://" + (fixture / f"{clip}_candidate.tres").relative_to(GODOT).as_posix()
            isolated = subprocess.run(
                [str(ENGINE), "--headless", "--path", str(GODOT),
                 "--script", "res://tests/actor_candidate_isolation.gd", "--",
                 f"--resource={resource}", f"--clip={clip}"],
                capture_output=True, text=True, encoding="utf-8", errors="replace",
                check=False,
            )
            print(isolated.stdout, isolated.stderr)
            if isolated.returncode != 0 or "ACTOR_CANDIDATE_ISOLATION_PASS" not in isolated.stdout:
                raise AssertionError(f"{clip} candidate inherited unreviewed source animations")
        print("REVIEWED_SEQUENCE_GATE_PASS distinct=32 repeated=1_rejected sparse_edits=rejected idle_saved=true wide_action_saved=true")
    finally:
        # Windows cleanup only after verifying the resolved absolute directory.
        if fixture.is_relative_to(GODOT.resolve()) and fixture.name.startswith("_frame32_validation_"):
            shutil.rmtree(fixture)


if __name__ == "__main__":
    main()
