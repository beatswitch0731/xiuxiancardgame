"""Assemble unchanged Godot render frames into small review GIFs."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
FRAMES = (
    ROOT
    / "artifacts"
    / "godot-migration"
    / "first-fight-backend-qa"
    / "intent-slip-motion-v1"
)


def assemble(prefix: str, output_name: str) -> None:
    paths = sorted(FRAMES.glob(f"{prefix}_*.png"))
    if len(paths) != 24:
        raise ValueError(f"Expected 24 Godot frames for {prefix}, got {len(paths)}")
    frames = [Image.open(path).convert("RGB") for path in paths]
    palette_sheet = Image.new("RGB", (frames[0].width, frames[0].height * len(frames)))
    for index, frame in enumerate(frames):
        palette_sheet.paste(frame, (0, index * frame.height))
    palette = palette_sheet.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    indexed[0].save(
        FRAMES / output_name,
        save_all=True,
        append_images=indexed[1:],
        duration=75,
        loop=0,
        disposal=2,
        optimize=False,
    )


if __name__ == "__main__":
    assemble("frame", "enemy_intent_paper.gif")
    assemble("status", "battle_status_paper.gif")
