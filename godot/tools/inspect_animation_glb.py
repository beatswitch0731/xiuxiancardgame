"""List glTF animation clip names and skin joint names without importing the mesh."""

import json
from pathlib import Path
import struct
import sys

path = Path(sys.argv[1])
with path.open("rb") as source:
    header = source.read(20)
    magic, version, total_length, chunk_length, chunk_type = struct.unpack("<4sIIII", header)
    if magic != b"glTF" or version != 2 or chunk_type != 0x4E4F534A:
        raise SystemExit("Not a glTF 2.0 binary JSON chunk")
    data = json.loads(source.read(chunk_length))
print("GLB", path, "bytes", total_length)
print("SKINS", len(data.get("skins", [])))
for skin in data.get("skins", []):
    print("JOINTS", [data["nodes"][index].get("name") for index in skin["joints"]])
print("ANIMATIONS", len(data.get("animations", [])))
for animation in data.get("animations", []):
    print(animation.get("name", "<unnamed>"))
