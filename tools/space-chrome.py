#!/usr/bin/env python3
"""Install the Claude Space look (space/chrome/claude-space.css.in + the pixel Claude
SVGs) into a Zen profile's chrome folder, with the id of the Space named NAME, and
@import it from userChrome.css. Idempotent; Zen picks it up at its next start.

    tools/space-chrome.py [--profile DIR] [--space NAME]
"""
import argparse, os, pathlib, shutil, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mozlz4  # noqa: E402
from importlib import util as _u  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent.parent
_spec = _u.spec_from_file_location("asr", HERE / "tools/add-space-route.py")
asr = _u.module_from_spec(_spec); _spec.loader.exec_module(asr)
IMPORT = '@import "claude-space.css";  /* claude-zen-sandbox */\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", type=pathlib.Path)
    ap.add_argument("--space", default="Claude")
    a = ap.parse_args()
    profile = a.profile or asr.default_profile()
    spaces = mozlz4.read(profile / "zen-sessions.jsonlz4").get("spaces", [])
    space = next((s for s in spaces if s.get("name") == a.space), None)
    if not space:
        sys.exit(f'no Space named "{a.space}" in {profile.name}')
    chrome = profile / "chrome"
    chrome.mkdir(exist_ok=True)
    css = (HERE / "space/chrome/claude-space.css.in").read_text().replace("@SPACE@", space["uuid"])
    (chrome / "claude-space.css").write_text(css)
    for mood in ("idle", "reading", "acting"):
        shutil.copyfile(HERE / f"profile/chrome/critter-{mood}.svg", chrome / f"claude-critter-{mood}.svg")
    uc = chrome / "userChrome.css"
    text = uc.read_text() if uc.exists() else ""
    if IMPORT.strip() not in text:
        with open(uc, "r+" if uc.exists() else "w") as f:   # in place, @import has to come first
            f.seek(0); f.write(IMPORT + text); f.truncate()
    print(f'Claude Space look installed in {profile.name}/chrome ({space["uuid"]})')


if __name__ == "__main__":
    main()
