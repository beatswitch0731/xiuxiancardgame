"""Encode the four Godot review captures as a short, inspectable motion loop."""

from pathlib import Path
import argparse

import imageio_ffmpeg
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
CAPTURES = ROOT / "artifacts/godot-migration/first-fight-backend-qa"
DURATIONS = [0.54, 0.46, 0.58, 0.48]
FPS = 30


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", choices=("default", "breath_v17"), default="default")
    candidate = parser.parse_args().candidate
    output = CAPTURES / f"{candidate}-opening-breath-review.mp4"
    frames = [
        Image.open(CAPTURES / f"{candidate}-forward_plus-yaw0-pose-idle-frame-{index}.png").convert("RGB")
        for index in range(4)
    ]
    if len({frame.size for frame in frames}) != 1:
        raise RuntimeError("Breath review screenshots need the same camera and output size")
    writer = imageio_ffmpeg.write_frames(str(output), frames[0].size, fps=FPS,
                                          codec="libx264", pix_fmt_out="yuv420p", quality=8,
                                          output_params=["-movflags", "+faststart"])
    writer.send(None)
    for _loop in range(3):
        for frame, duration in zip(frames, DURATIONS):
            for _tick in range(round(duration * FPS)):
                writer.send(frame.tobytes())
    writer.close()
    print(f"BREATH_REVIEW_VIDEO_READY {output}")


if __name__ == "__main__":
    main()
