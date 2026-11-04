"""Use FrameRonin V3's actual multi-image UI to pack reviewed key poses.

Two cells per actor are a pose-board proof, not a claimed 32-frame animation.
Run with FrameRonin's local Vite frontend at http://127.0.0.1:5173.
"""

from pathlib import Path
import re
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "godot/art_source/actor_v4_keyframes"
OUTPUT = ROOT / "artifacts/godot-migration/actor-v4-keyframe-review"
OUTPUT.mkdir(parents=True, exist_ok=True)

PAIRS = (
    ("yelingyun", (
        "yelingyun_idle_common_canvas_512x320.png",
        "yelingyun_contact_scale_v3_single_keypose_review_v1.png",
    )),
    ("quick_sword_dummy", (
        "quick_sword_dummy_single_keypose_review_v1.png",
        "quick_sword_dummy_hit_single_keypose_review_v1.png",
    )),
)


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    )
    for actor, names in PAIRS:
        page = browser.new_page(viewport={"width": 1440, "height": 900}, accept_downloads=True)
        page.goto("http://127.0.0.1:5173", wait_until="networkidle")
        page.keyboard.press("c")
        page.get_by_role("tab", name="多图合成单图").click()
        page.get_by_text("多图导入", exact=True).click()
        active = page.locator(".ant-tabs-tabpane-active")
        active.locator('input[type="file"]').set_input_files([str(SOURCE / n) for n in names])
        cols = active.locator("input.ant-input-number-input").first
        cols.fill("2")
        cols.press("Tab")
        page.screenshot(path=str(OUTPUT / f"{actor}-frameronin-input-review.png"), full_page=True)
        print("FRAMERONIN_BUTTONS", ascii(page.locator("button").all_inner_texts()))
        page.locator("button").filter(has_text=re.compile(r"合\s*成")).last.click()
        page.locator("button").filter(has_text="下载图片").last.wait_for(timeout=15000)
        page.screenshot(path=str(OUTPUT / f"{actor}-frameronin-assembled-review.png"), full_page=True)
        with page.expect_download() as download_info:
            page.locator("button").filter(has_text="下载图片").last.click()
        download_info.value.save_as(OUTPUT / f"{actor}-frameronin-two-keypose-atlas.png")
        print(f"FRAMERONIN_V4_POSE_BOARD actor={actor} keyposes=2 runtime_animation=false")
        page.close()
    browser.close()
