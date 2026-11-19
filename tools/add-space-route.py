#!/usr/bin/env python3
"""Add the Zen space-routing rule that puts Claude's tabs in its Space:
"URL contains claude-space.html" -> the Space named NAME (default "Claude").

    tools/add-space-route.py [--profile DIR] [--space NAME]

Zen reads zen-space-routing.jsonlz4 at startup and rewrites it on exit, so the
file is only edited while that profile isn't running. Idempotent. Without
--profile it uses Zen's default profile (profiles.ini).
"""
import argparse, configparser, os, pathlib, sys, uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mozlz4  # noqa: E402

MARK = "claude-space.html"
ZEN = pathlib.Path.home() / ".config/zen"


def default_profile():
    ini = configparser.ConfigParser(interpolation=None)
    ini.read(ZEN / "profiles.ini")
    for sec in ini.sections():                      # the Install section names the default
        if sec.startswith("Install") and ini[sec].get("Default"):
            return ZEN / ini[sec]["Default"]
    for sec in ini.sections():
        if ini[sec].get("Default") == "1":
            return ZEN / ini[sec]["Path"]
    sys.exit("no default Zen profile found")


def running(profile):
    """True if a Zen instance has this profile open (its lock symlink points at a live pid)."""
    lock = profile / "lock"
    try:
        target = os.readlink(lock)                  # "ip:+pid"
        pid = int(target.rsplit("+", 1)[1])
        os.kill(pid, 0)
        return True
    except (OSError, ValueError, IndexError):
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", type=pathlib.Path)
    ap.add_argument("--space", default="Claude")
    a = ap.parse_args()
    profile = a.profile or default_profile()

    spaces = mozlz4.read(profile / "zen-sessions.jsonlz4").get("spaces", [])
    space = next((s for s in spaces if s.get("name") == a.space), None)
    if not space:
        sys.exit(f'no Space named "{a.space}" in {profile.name}: create it in Zen first')

    path = profile / "zen-space-routing.jsonlz4"
    data = mozlz4.read(path) if path.exists() else {}
    routes = data.setdefault("routes", [])
    data.setdefault("defaultRouteExternal", "most-recent-space")
    for r in routes:
        if r.get("reference") == MARK:
            if r.get("openIn") == space["uuid"]:
                print(f'rule already there: {MARK} -> "{a.space}"')
                return 0
            break
    if running(profile):
        sys.exit("Zen is running with this profile: quit it (all windows), then run this again")
    routes[:] = [r for r in routes if r.get("reference") != MARK]
    routes.append({"id": str(uuid.uuid4()), "reference": MARK, "openIn": space["uuid"], "matchType": "contains"})
    mozlz4.write(path, data)
    print(f'added: {MARK} -> "{a.space}" ({space["uuid"]}) in {profile.name}')
    return 0


if __name__ == "__main__":
    sys.exit(main())
