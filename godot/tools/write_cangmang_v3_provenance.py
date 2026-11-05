"""Record every source and generated output used by the V3 court candidate."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT / "art_source"
V3 = SOURCE / "cangmang_court_v3"
GROUPS = [
    {
        "name": "Chinese four-corner pavilion",
        "upstream": "https://store.godotengine.org/asset/vvaytoyek/chinese-four-corner-pavilion-free/",
        "license": "CC0 1.0 Universal",
        "paths": [SOURCE / "vendor_candidates/chinese_four_corner_pavilion.zip",
                  SOURCE / "vendor_candidates/chinese_four_corner_pavilion"],
    },
    {
        "name": "Chinese classical garden wall",
        "upstream": "https://store.godotengine.org/asset/vvaytoyek/chinese-classical-garden-wall/",
        "license": "CC0 1.0 Universal",
        "paths": [SOURCE / "vendor_candidates/chinese_classical_garden_wall.zip",
                  SOURCE / "vendor_candidates/chinese_classical_garden_wall"],
    },
    {
        "name": "Chinese chandelier",
        "upstream": "https://polyhaven.com/a/chinese_chandelier",
        "license": "CC0",
        "paths": [SOURCE / "vendor_candidates/chinese_chandelier"],
    },
    {
        "name": "Pine sapling small",
        "upstream": "https://polyhaven.com/a/pine_sapling_small",
        "license": "CC0",
        "paths": [SOURCE / "vendor_candidates/pine_sapling_small"],
    },
    {
        "name": "Rectangular paving PBR",
        "upstream": "https://polyhaven.com/a/rectangular_paving",
        "license": "CC0",
        "paths": [V3 / "textures/rectangular_paving_diff_2k.jpg",
                  V3 / "textures/rectangular_paving_nor_gl_2k.jpg",
                  V3 / "textures/rectangular_paving_rough_2k.jpg"],
    },
    {
        "name": "Distant mountain and sky layer",
        "upstream": "art_direction/prompts/ENV-CANGMANG-FAR-VISTA-04.md",
        "license": "Project-generated ImageGen candidate; see prompt and raw source",
        "paths": [V3 / "textures/cangmang_far_vista.png",
                  PROJECT / "art_direction/prompts/ENV-CANGMANG-FAR-VISTA-04.md"],
    },
    {
        "name": "Inherited V2 authored court and PBR resources",
        "upstream": "art_source/cangmang_court_v2",
        "license": "Project-authored geometry; inherited Poly Haven materials recorded in V2 manifests",
        "paths": [SOURCE / "cangmang_court_v2/cangmang_court_v2.blend",
                  SOURCE / "cangmang_court_v2/textures/polyhaven_manifest.json",
                  SOURCE / "cangmang_court_v2/props/chinese_chandelier/source_manifest.json"],
    },
]


def record(path: Path) -> dict[str, str | int]:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return {"path": path.relative_to(PROJECT).as_posix(), "sha256": digest.hexdigest(),
            "bytes": path.stat().st_size}


def files(paths: list[Path]) -> list[Path]:
    found: set[Path] = set()
    for path in paths:
        if not path.exists():
            raise FileNotFoundError(path)
        if path.is_file():
            found.add(path)
        else:
            found.update(item for item in path.rglob("*") if item.is_file())
    return sorted(found)


def main() -> None:
    output = {
        "status": "visual candidate only; not accepted as P2-equivalent",
        "pipeline": "Blender 5.2.2 LTS -> glTF 2.0 GLB -> Godot 4.7.2 Forward+",
        "rebuild": "blender -b -t 8 art_source/cangmang_court_v2/cangmang_court_v2.blend --python art_source/cangmang_court_v3/build_outdoor_court.py",
        "sources": [{key: value for key, value in group.items() if key != "paths"}
                    | {"files": [record(path) for path in files(group["paths"])]}
                    for group in GROUPS],
        "authoring": [record(V3 / "build_outdoor_court.py"),
                      record(V3 / "cangmang_outdoor_court_v3.blend")],
        "runtime": [record(PROJECT / "assets/battle/hd2d/world_v3/cangmang_outdoor_court_v3.glb")],
    }
    target = V3 / "source_manifest.json"
    target.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"V3_SOURCE_MANIFEST_READY groups={len(GROUPS)} files="
          f"{sum(len(group['files']) for group in output['sources'])} path={target}")


if __name__ == "__main__":
    main()
