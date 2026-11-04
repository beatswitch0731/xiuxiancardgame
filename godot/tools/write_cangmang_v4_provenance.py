"""Record the editable V4 court and source asset hashes after export."""

import hashlib
import json
from pathlib import Path

project = Path(__file__).resolve().parents[1]
repo = project.parent
paths = [
    "tools/fetch_polyhaven_rock_moss_set.py",
    "art_source/cangmang_court_v4/build_trial_court.py",
    "art_source/cangmang_court_v4/cangmang_trial_court_v4.blend",
    "assets/hd2d/world_v4/cangmang_trial_court_v4.glb",
    "art_source/cangmang_court_v3/cangmang_outdoor_court_v3.blend",
    "art_source/cangmang_court_v3/source_manifest.json",
    "art_source/cangmang_court_v3/textures/monastery_stone_floor_diff_2k.jpg",
    "art_source/cangmang_court_v3/textures/monastery_stone_floor_nor_gl_2k.jpg",
    "art_source/cangmang_court_v3/textures/monastery_stone_floor_rough_2k.jpg",
    "art_source/vendor_candidates/rock_moss_set_01/rock_moss_set_01_2k.gltf",
    "art_source/vendor_candidates/rock_moss_set_01/rock_moss_set_01.bin",
    "art_source/vendor_candidates/rock_moss_set_01/textures/rock_moss_set_01_diff_2k.jpg",
    "art_source/vendor_candidates/rock_moss_set_01/textures/rock_moss_set_01_nor_gl_2k.jpg",
    "art_source/vendor_candidates/rock_moss_set_01/textures/rock_moss_set_01_rough_2k.jpg",
]
records = []
for relative in paths:
    item = project / relative
    digest = hashlib.sha256()
    with item.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    records.append({"path": relative, "bytes": item.stat().st_size,
                    "sha256": digest.hexdigest()})

manifest = {
    "status": "isolated V4 visual candidate; P2 art review FAIL; not the default battle scene",
    "source_identity": str((repo / "assets/combat/battlefields/battlefield_enc_trial_sword_swift_agc_v2.png").relative_to(repo)).replace("\\", "/"),
    "pipeline": "Blender 5.2.2 .blend -> GLB -> Godot 4.7.2 Forward+",
    "rebuild": "blender -b godot/art_source/cangmang_court_v3/cangmang_outdoor_court_v3.blend --python godot/art_source/cangmang_court_v4/build_trial_court.py",
    "new_scanned_stone": {"url": "https://polyhaven.com/a/monastery_stone_floor",
                          "license": "CC0 1.0 Universal"},
    "new_scanned_rock_set": {"url": "https://polyhaven.com/a/rock_moss_set_01",
                             "license": "CC0 1.0 Universal",
                             "upstream_manifest": "https://api.polyhaven.com/files/rock_moss_set_01"},
    "other_inherited_sources": "art_source/cangmang_court_v3/source_manifest.json",
    "files": records,
}
output = project / "art_source/cangmang_court_v4/source_manifest.json"
output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(output)
