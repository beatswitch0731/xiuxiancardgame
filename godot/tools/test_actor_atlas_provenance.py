"""Exercise the real source-to-atlas failure modes with disposable images."""

from __future__ import annotations

import hashlib
import tempfile
from pathlib import Path

from PIL import Image

from verify_actor_atlas_provenance import ROOT, verify


def main() -> None:
    parent = ROOT / "godot" / "art_source"
    with tempfile.TemporaryDirectory(prefix="_atlas_provenance_", dir=parent) as directory:
        fixture = Path(directory)
        images = []
        frames = []
        for number, color in enumerate(((33, 68, 95, 255), (190, 99, 44, 255))):
            image = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
            image.putpixel((number + 1, 1), color)
            path = fixture / f"frame_{number}.png"
            image.save(path)
            images.append(image)
            frames.append({"source": path.relative_to(ROOT).as_posix(),
                           "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                           "artSetId": "fixture_art", "canvas": {"w": 4, "h": 4}})
        atlas = Image.new("RGBA", (8, 4))
        for number, image in enumerate(images):
            atlas.paste(image, (number * 4, 0))
        sheet = fixture / "sheet.png"
        atlas.save(sheet)
        manifest = {"actorId": "yelingyun_s1", "artSetId": "fixture_art",
                    "clips": {"idle": frames}}
        index = {"actorId": "yelingyun_s1", "artSetId": "fixture_art",
                 "frames": [{"x": number * 4, "y": 0, "w": 4, "h": 4,
                             "source_sha256": frame["sha256"]}
                            for number, frame in enumerate(frames)]}
        assert not verify(manifest, "idle", sheet, index)

        reordered = {**index, "frames": list(reversed(index["frames"]))}
        assert any("points to another source" in error for error in
                   verify(manifest, "idle", sheet, reordered))

        atlas.putpixel((1, 1), (35, 68, 95, 255))
        atlas.save(sheet)
        assert any("atlas pixels differ" in error for error in
                   verify(manifest, "idle", sheet, index))

        cropped = {**index, "frames": [dict(index["frames"][0], w=3), index["frames"][1]]}
        assert any("cropped, scaled" in error for error in
                   verify(manifest, "idle", sheet, cropped))

        atlas.paste(images[0], (0, 0))
        atlas.save(sheet)
        frames[0]["sha256"] = "0" * 64
        assert any("frozen source SHA-256" in error for error in
                   verify(manifest, "idle", sheet, index))
    print("ACTOR_ATLAS_PROVENANCE_TEST_PASS exact=reproduced reorder=blocked "
          "changed_pixel=blocked crop=blocked source_mutation=blocked")


if __name__ == "__main__":
    main()
