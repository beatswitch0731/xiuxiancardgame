"""Pack both four-phase idle clips in the real FrameRonin UI and verify pixels."""

from pathlib import Path
import re

from PIL import Image
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "godot/assets/source_first_fight/breath_v17"
EVIDENCE = ROOT / "artifacts/godot-migration/breath-v17-frameronin"
EVIDENCE.mkdir(parents=True, exist_ok=True)


def verify_sheet(actor: str, sheet_path: Path) -> None:
    with Image.open(sheet_path) as opened:
        sheet = opened.convert("RGBA")
    if sheet.size != (640, 640):
        raise RuntimeError(f"FrameRonin changed the {actor} atlas dimensions: {sheet.size}")
    for index in range(4):
        source_path = SOURCE / f"{actor}_{index:02d}.png"
        with Image.open(source_path) as opened:
            frame = opened.convert("RGBA")
        x, y = index % 2 * 320, index // 2 * 320
        actual = sheet.crop((x, y, x + 320, y + 320))
        # Browser canvas preserves alpha exactly. Its PNG round-trip can
        # re-quantize RGB at translucent anti-aliased edges by 1-10 levels;
        # fully opaque artwork must remain byte-for-byte identical.
        for actual_pixel, source_pixel in zip(actual.get_flattened_data(), frame.get_flattened_data()):
            alpha = source_pixel[3]
            if actual_pixel[3] != alpha:
                raise RuntimeError(f"FrameRonin changed {actor} phase {index} alpha")
            if alpha == 0:
                continue
            delta = max(abs(a - b) for a, b in zip(actual_pixel[:3], source_pixel[:3]))
            limit = 0 if alpha == 255 else max(1, round(128 / alpha))
            if delta > limit:
                raise RuntimeError(f"FrameRonin changed {actor} phase {index} visible color")
    print(f"FRAMERONIN_BREATH_PIXELS_PASS actor={actor} cells=4 opaque_exact=true alpha_exact=true atlas={sheet_path}")


def main() -> None:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        )
        for actor in ("yelingyun", "quick_sword_dummy"):
            page = browser.new_page(viewport={"width": 1440, "height": 900}, accept_downloads=True)
            page.goto("http://127.0.0.1:5173", wait_until="networkidle")
            page.keyboard.press("c")
            page.get_by_role("tab", name="多图合成单图").click()
            page.get_by_text("多图导入", exact=True).click()
            active = page.locator(".ant-tabs-tabpane-active")
            paths = [str(SOURCE / f"{actor}_{index:02d}.png") for index in range(4)]
            active.locator('input[type="file"]').set_input_files(paths)
            columns = active.locator("input.ant-input-number-input").first
            columns.fill("2")
            columns.press("Tab")
            page.screenshot(path=str(EVIDENCE / f"{actor}-input.png"), full_page=True)
            page.locator("button").filter(has_text=re.compile(r"合\s*成")).last.click()
            download = page.locator("button").filter(has_text="下载图片").last
            download.wait_for(timeout=15000)
            page.screenshot(path=str(EVIDENCE / f"{actor}-assembled.png"), full_page=True)
            with page.expect_download() as receipt:
                download.click()
            atlas = SOURCE / f"frameronin_{actor}_idle_sheet.png"
            receipt.value.save_as(atlas)
            verify_sheet(actor, atlas)
            page.close()
        browser.close()


if __name__ == "__main__":
    main()
