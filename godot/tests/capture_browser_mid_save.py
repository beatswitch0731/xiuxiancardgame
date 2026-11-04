"""Capture a real browser save10 export after avoiding the first sword trial."""

import hashlib
import json
from pathlib import Path

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "artifacts/godot-migration/noncombat-browser-import/mid-source-save-sword.json"
CHROME = Path("C:/Program Files/Google/Chrome/Application/chrome.exe")
URL = "http://127.0.0.1:1979/?e2e=combat&batch=browser-mid-save-import"
DIRECTIONS = ("right", "left", "left", "right", "left", "left")
SOURCES = (
    "src/core/GameStateManager.js",
    "src/game.js",
    "src/systems/FlowDirector.js",
    "src/systems/MarketSystem.js",
    "src/systems/HeavensHintSystem.js",
    "src/systems/LegacyFragmentSystem.js",
    "src/systems/NarrativeLedger.js",
    "src/systems/EncounterDirector.js",
    "src/systems/WorldPulseSystem.js",
    "src/systems/KarmaRippleSystem.js",
)


def main() -> None:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=str(CHROME), headless=True)
        page = browser.new_page(viewport={"width": 1280, "height": 800})
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        try:
            page.goto(URL, wait_until="networkidle", timeout=120000)
            page.evaluate("localStorage.clear()")
            page.reload(wait_until="networkidle", timeout=120000)
            page.wait_for_function("window.__combatE2E?.game && window.__combatE2E?.ui")
            page.evaluate("window.__combatE2E.ui.startGame('sword')")
            snapshots = []
            for direction in (None, *DIRECTIONS):
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
            OUTPUT.parent.mkdir(parents=True, exist_ok=True)
            OUTPUT.write_text(
                json.dumps(
                    {
                        "source": "live browser",
                        "path": "sword",
                        "directions": DIRECTIONS,
                        "sourceHashes": {
                            name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                            for name in SOURCES
                        },
                        "snapshots": snapshots,
                    },
                    ensure_ascii=False,
                    indent=2,
                )
                + "\n",
                encoding="utf-8",
            )
            for index, row in enumerate(snapshots):
                save = json.loads(row["storage"]["xiuxian_unlocks"])
                causal = save["causalSessionState"]
                print(
                    index,
                    row["visibleCardId"],
                    causal["runClock"]["decisionIndex"],
                    causal.get("flowState", {}).get("phase"),
                    "combat=" + str(causal.get("combatSession") is not None),
                )
        finally:
            browser.close()


if __name__ == "__main__":
    main()
