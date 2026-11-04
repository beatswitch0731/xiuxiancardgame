"""Fetch the CC0 Poly Haven 2K mossy rock set with upstream hashes."""

import hashlib
import json
import urllib.request
from pathlib import Path

source = "https://api.polyhaven.com/files/rock_moss_set_01"
def open_url(url):
    request = urllib.request.Request(url, headers={"User-Agent": "YiNianXianTu-AssetResearch/1.0"})
    return urllib.request.urlopen(request, timeout=30)


manifest = json.load(open_url(source))
entry = manifest["gltf"]["2k"]["gltf"]
root = Path(__file__).resolve().parents[1] / "art_source/vendor_candidates/rock_moss_set_01"
download = {"rock_moss_set_01_2k.gltf": entry}
download.update(entry["include"])
for relative, info in download.items():
    target = root / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists() or hashlib.md5(target.read_bytes()).hexdigest() != info["md5"]:
        with open_url(info["url"]) as remote, target.open("wb") as local:
            while block := remote.read(1024 * 1024):
                local.write(block)
    if hashlib.md5(target.read_bytes()).hexdigest() != info["md5"]:
        raise RuntimeError("Upstream MD5 mismatch: " + relative)
print("CC0_ROCK_SET_READY", root)
