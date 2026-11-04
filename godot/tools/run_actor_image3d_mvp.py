"""Submit one reviewed Ye Lingyun concept to Tencent's official Hunyuan3D Space.

This is an isolated candidate experiment. The output mesh is not rigged and
must not be mounted as a finished combat actor without a turntable review.
"""

from pathlib import Path
import json
import shutil
import sys

from gradio_client import Client, handle_file


def main() -> None:
    source = Path(sys.argv[1]).resolve()
    destination = Path(sys.argv[2]).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    mode = sys.argv[3] if len(sys.argv) > 3 else "shape"
    multiview = mode == "multiview"
    client = Client("tencent/Hunyuan3D-2mv" if multiview else "tencent/Hunyuan3D-2.1")
    kwargs = dict(
        image=None if multiview else handle_file(str(source)),
        mv_image_front=handle_file(str(source)) if multiview else None,
        mv_image_back=handle_file(sys.argv[4]) if multiview else None,
        mv_image_left=handle_file(sys.argv[5]) if multiview else None,
        mv_image_right=None,
        steps=10 if multiview else 30,
        guidance_scale=5.0,
        seed=240719,
        octree_resolution=256,
        check_box_rembg=True,
        num_chunks=8000,
        randomize_seed=False,
    )
    print("IMAGE3D_SUBMIT", source, flush=True)
    if multiview:
        kwargs["caption"] = None
    endpoint = "/generation_all" if mode == "all" else "/shape_generation"
    result = client.predict(**kwargs, api_name=endpoint)
    print("IMAGE3D_RESULT_TYPES", [type(part).__name__ for part in result], flush=True)
    files = []
    for index, part in enumerate(result):
        candidate = part.get("value") if isinstance(part, dict) else part
        if isinstance(candidate, str) and Path(candidate).is_file():
            target = destination / f"hunyuan3d_{mode}_output_{index}{Path(candidate).suffix}"
            shutil.copyfile(candidate, target)
            files.append(str(target))
    (destination / f"hunyuan3d_21_{mode}_result.json").write_text(
        json.dumps({"source": str(source), "files": files,
                    "metadata": [str(p)[:1000] for p in result]}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print("IMAGE3D_SAVED", files, flush=True)


if __name__ == "__main__":
    main()
