"""Capture real browser save10 exports at the first three noncombat decisions."""

import hashlib
import json
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parent.parent
PATH_ID = sys.argv[1] if len(sys.argv) > 1 else "sword"
if PATH_ID not in ("sword", "spell", "body", "pill"):
    raise SystemExit("path must be sword, spell, body or pill")
OUTPUT = ROOT / "godot/output/captures/godot-migration/noncombat-browser-import" / (
    "opening-source-saves.json" if PATH_ID == "sword"
    else f"opening-source-saves-{PATH_ID}.json"
)
BASE_URL = "http://127.0.0.1:1979/?e2e=combat&batch=browser-save-import"
CHROME = Path("C:/Program Files/Google/Chrome/Application/chrome.exe")


def main() -> None:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=str(CHROME), headless=True
        )
        page = browser.new_page(viewport={"width": 1280, "height": 800})
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        try:
            page.goto(BASE_URL, wait_until="networkidle", timeout=120000)
            page.evaluate("localStorage.clear()")
            errors.clear()
            page.reload(wait_until="networkidle", timeout=120000)
            page.wait_for_function("window.__combatE2E?.game && window.__combatE2E?.ui")
            page.evaluate("path => window.__combatE2E.ui.startGame(path)", PATH_ID)
            snapshots = []
            for direction in (None, "right", "left", "left"):
                if direction is not None:
                    accepted = page.evaluate(
                        "direction => {const game = window.__combatE2E.game;"
                        "return game.makeChoice(direction, game.issueChoiceToken());}",
                        direction,
                    )
                    if not accepted:
                        raise RuntimeError(f"Browser rejected {direction}")
                captured = page.evaluate(
                    """() => ({
                      storage: {
                        xiuxian_unlocks: localStorage.getItem('xiuxian_unlocks'),
                        xiuxian_active_save_slot: localStorage.getItem('xiuxian_active_save_slot')
                      },
                      visibleCardId: window.__combatE2E.game.getCurrentCard()?.id || null
                    })"""
                )
                if not captured["storage"]["xiuxian_unlocks"]:
                    raise RuntimeError("Browser did not persist save10")
                snapshots.append(captured)
            if errors:
                raise RuntimeError("Browser page errors: " + "; ".join(errors))
            sources = (
                "src/core/GameStateManager.js", "src/game.js",
                "src/systems/MarketSystem.js", "src/systems/HeavensHintSystem.js",
                "src/systems/LegacyFragmentSystem.js", "src/systems/FlowDirector.js",
                "src/systems/NarrativeLedger.js",
            )
            source_hashes = {
                name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                for name in sources
                if (ROOT / name).exists()
            }
            OUTPUT.parent.mkdir(parents=True, exist_ok=True)
            OUTPUT.write_text(
                json.dumps(
                    {"source": "live browser", "path": PATH_ID,
                     "directions": ["right", "left", "left"], "sourceHashes": source_hashes,
                     "snapshots": snapshots},
                    ensure_ascii=False, indent=2,
                ) + "\n",
                encoding="utf-8",
            )
            print(
                "NONCOMBAT_BROWSER_SAVE_OPENING_PASS cards="
                + ">".join(str(row["visibleCardId"]) for row in snapshots)
            )
        finally:
            browser.close()


if __name__ == "__main__":
    main()
