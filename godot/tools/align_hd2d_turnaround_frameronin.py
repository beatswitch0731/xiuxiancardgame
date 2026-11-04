"""Align an isolated eight-view candidate through FrameRonin V3's UI.

Run under the local FrameRonin Vite server via webapp-testing/with_server.py.
The input is intentionally an art candidate; this does not mount runtime art.
"""

from pathlib import Path

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
CANDIDATES = ROOT / "godot/art_direction/candidates/HD2D-CHAR-01"
SOURCE = CANDIDATES / "yelingyun_turnaround_v2.png"
OUTPUT = CANDIDATES / "yelingyun_turnaround_v2_frameronin_aligned.png"
FRAME_DY = (-23, -23, -23, -21, 3, 2, 0, 0)


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True, executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe"
    )
    page = browser.new_page(viewport={"width": 1440, "height": 900}, accept_downloads=True)
    page.goto("http://127.0.0.1:5173", wait_until="networkidle")
    page.keyboard.press("n")
    page.locator('input[type="file"]').set_input_files(str(SOURCE))
    text_fields = page.locator("input:not([type])")
    for index, value in enumerate(("4", "2", "4")):
        text_fields.nth(index).fill(value)
        text_fields.nth(index).press("Tab")
    page.get_by_text("共 8 帧", exact=False).first.wait_for()
    page.wait_for_timeout(800)
    up = page.locator('button[title="上移 1 像素"]')
    down = page.locator('button[title="下移 1 像素"]')
    assert up.count() >= 8 and down.count() >= 8
    for frame_index, dy in enumerate(FRAME_DY):
        direction = up if dy < 0 else down
        for _ in range(abs(dy)):
            direction.nth(frame_index).click()
        if dy != 0:
            for _ in range(8):
                count = direction.nth(frame_index).inner_text().strip()
                if count.isdigit() and int(count) >= abs(dy):
                    break
                direction.nth(frame_index).click()
            else:
                raise RuntimeError(f"FrameRonin did not record all shifts for frame {frame_index}")
    page.get_by_role("button", name="重组合", exact=True).last.click()
    link = page.locator('a[download^="recombined_"]')
    link.wait_for()
    with page.expect_download() as download_info:
        link.click()
    download_info.value.save_as(OUTPUT)
    page.screenshot(path=str(CANDIDATES / "frameronin-aligned-workflow.png"), full_page=True)
    print(f"FRAMERONIN_ALIGN_PASS {OUTPUT} offsets={FRAME_DY}")
    browser.close()
