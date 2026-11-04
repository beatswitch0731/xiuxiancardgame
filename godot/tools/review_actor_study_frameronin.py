"""Run FrameRonin V3's actual sheet UI on rejected eight-pose studies.

Requires the local Vite frontend on http://127.0.0.1:5173. Output is QA
evidence only; these sheets must not be mounted as animation resources.
"""

from pathlib import Path
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "godot/art_source/actor_v3_sprite"
OUTPUT = ROOT / "artifacts/godot-migration/actor-v3-frameronin-review"
OUTPUT.mkdir(parents=True, exist_ok=True)


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    )
    for actor, image in (
        ("hero", "yelingyun_pixel_sequence_study_candidate_v1.png"),
        ("dummy", "quick_sword_dummy_pixel_sequence_study_candidate_v1.png"),
    ):
        page = browser.new_page(viewport={"width": 1440, "height": 900}, accept_downloads=True)
        page.goto("http://127.0.0.1:5173", wait_until="networkidle")
        page.screenshot(path=str(OUTPUT / f"{actor}-home-debug.png"), full_page=True)
        page.keyboard.press("n")
        page.screenshot(path=str(OUTPUT / f"{actor}-after-n-debug.png"), full_page=True)
        page.locator('input[type="file"]').set_input_files(str(SOURCE / image))
        fields = page.locator("input:not([type])")
        for index, value in enumerate(("4", "2", "4")):
            fields.nth(index).fill(value)
            fields.nth(index).press("Tab")
        page.get_by_text("共 8 帧", exact=False).first.wait_for(timeout=15000)
        page.screenshot(path=str(OUTPUT / f"{actor}-eight-cell-review.png"), full_page=True)
        page.get_by_role("button", name="重组合", exact=True).last.click()
        link = page.locator('a[download^="recombined_"]')
        link.wait_for(timeout=15000)
        with page.expect_download() as download_info:
            link.click()
        download_info.value.save_as(OUTPUT / f"{actor}-frameronin-recombined-review.png")
        print(f"FRAMERONIN_STUDY_IMPORTED actor={actor} cells=8 runtime_approved=false")
        page.close()
    browser.close()
