"""Crop the authored HUD materials without changing their painted content.

Raw ImageGen outputs and their individual prompts live under art_source/ui_hud_v1.
Keep them there so the runtime textures can be rebuilt without another generation.
"""

from pathlib import Path

from PIL import Image


GODOT = Path(__file__).resolve().parents[1]
SOURCE = GODOT / "art_source" / "ui_hud_v1" / "raw"
DESTINATION = GODOT / "assets" / "ui" / "hud_materials"


def prepare(name: str, output_size: tuple[int, int]) -> None:
    source = Image.open(SOURCE / f"{name}.png").convert("RGBA")
    alpha = source.getchannel("A")
    visible = alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()
    if visible is None:
        raise ValueError(f"{name}: no visible material")
    left, top, right, bottom = visible
    margin = 8
    region = source.crop(
        (
            max(0, left - margin),
            max(0, top - margin),
            min(source.width, right + margin),
            min(source.height, bottom + margin),
        )
    )
    region = region.resize(output_size, Image.Resampling.LANCZOS)
    DESTINATION.mkdir(parents=True, exist_ok=True)
    region.save(DESTINATION / f"{name}.png", optimize=True)


if __name__ == "__main__":
    prepare("status_plaque_v1", (730, 90))
    prepare("intent_slip_v1", (730, 100))
    prepare("card_inspect_folio_v1", (640, 300))
