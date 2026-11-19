#!/bin/bash
# claude-zen-sandbox: Claude drives Zen through a patched Claudezilla, in one of two modes.
#
#   ./install.sh             Space mode (default): a "Claude" Space in your own Zen profile,
#                            signed in as you. Claude's tabs open in the background there
#                            (a Zen space-routing rule), it only acts on tabs it opened, and
#                            your other tabs only through attach (Allow card in the island).
#   ./install.sh --profile   Separate profile: ~/.config/zen/claude, its own logins, run by
#                            zen-claude.service. Your own Zen never gets the add-on.
#
# Safe to re-run (updates in place). Root is needed once, for the native-messaging file
# Zen reads (pkexec). Space mode needs the add-on signed by Mozilla: put your
# addons.mozilla.org API key in ~/.config/claude-zen-sandbox/amo.env (tools/set-amo-key.sh).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MODE=space; [ "${1:-}" = "--profile" ] && MODE=profile
CZ_TAG="${CZ_TAG:-v0.7.7}"                                  # Claudezilla version (host + MCP server)
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CZ="$DATA/claudezilla"
OWN="$DATA/claude-zen-sandbox"                              # web-ext, signed builds
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
PROFILE="$CFG/zen/claude"
AMO_ENV="$CFG/claude-zen-sandbox/amo.env"
ADDON_ID="claude-zen@aphesist"
SYS_MANIFEST=/usr/lib/mozilla/native-messaging-hosts/claudezilla.json
say() { printf '\n== %s\n' "$*"; }

for c in git node npm jq zip zen-browser systemctl python3; do
    command -v "$c" >/dev/null || { echo "missing: $c"; exit 1; }
done
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

say "Claudezilla $CZ_TAG (native host + MCP server) in $CZ"
if [ -d "$CZ/.git" ]; then
    git -C "$CZ" fetch -q --depth 1 origin tag "$CZ_TAG"
    git -C "$CZ" -c advice.detachedHead=false checkout -q "$CZ_TAG"
else
    git clone -q --depth 1 --branch "$CZ_TAG" https://github.com/boot-industries/claudezilla.git "$CZ"
fi
# our changes on top (patches/): 0001 the MCP server (one agent per client, kept tabs,
# Space mode), 0002 the add-on (Space mode, ownership, the look, our add-on id)
git -C "$CZ" reset -q 2>/dev/null || true
git -C "$CZ" checkout -q -- . 2>/dev/null || true
git -C "$CZ" clean -qfd extension 2>/dev/null || true
for p in "$HERE"/patches/*.patch; do git -C "$CZ" apply "$p"; done
# its dependencies, without running any package install scripts
(cd "$CZ/mcp" && npm install --quiet --ignore-scripts --no-audit --no-fund)
printf '#!/bin/bash\nexec %s "%s/host/index.js" "$@"\n' "$(command -v node)" "$CZ" > "$CZ/host/run.sh"
chmod 755 "$CZ/host/run.sh" "$CZ/host/index.js"
VER=$(jq -r .version "$CZ/extension/manifest.json")

say "The add-on ($ADDON_ID $VER)"
SIGNED=$(ls "$OWN"/signed/*-"$VER".xpi 2>/dev/null | head -1 || true)
if [ -z "$SIGNED" ] && [ -f "$AMO_ENV" ]; then
    # Signed by Mozilla as a private (unlisted) add-on of your addons.mozilla.org account
    if [ ! -x "$OWN/web-ext/node_modules/.bin/web-ext" ]; then
        mkdir -p "$OWN/web-ext"
        (cd "$OWN/web-ext" && npm install --quiet --no-audit --no-fund --ignore-scripts web-ext)
    fi
    ( set -a; . "$AMO_ENV"; set +a
      cd "$TMP" && "$OWN/web-ext/node_modules/.bin/web-ext" sign --source-dir "$CZ/extension" \
          --artifacts-dir "$OWN/signed" --channel unlisted --no-input \
          --api-key "$AMO_JWT_ISSUER" --api-secret "$AMO_JWT_SECRET" 2>&1 | grep -v -i 'secret' )
    SIGNED=$(ls "$OWN"/signed/*-"$VER".xpi 2>/dev/null | head -1 || true)
fi
if [ -n "$SIGNED" ]; then
    echo "  signed: $SIGNED"
elif [ "$MODE" = space ]; then
    echo "  Space mode needs it signed: save your addons.mozilla.org API key with tools/set-amo-key.sh, then re-run."
    exit 1
fi

say "Native-messaging file (Zen only reads the system-wide folder)"
sed "s|@HOST@|$CZ/host/run.sh|" "$HERE/native/claudezilla.json.in" > "$TMP/claudezilla.json"
if ! cmp -s "$TMP/claudezilla.json" "$SYS_MANIFEST" 2>/dev/null; then
    pkexec install -D -m 644 "$TMP/claudezilla.json" "$SYS_MANIFEST"
fi
# per-user copies that Zen ignores, left over from earlier attempts
rm -f "$CFG/zen/native-messaging-hosts/claudezilla.json" "$CFG/mozilla/native-messaging-hosts/claudezilla.json"

if [ "$MODE" = space ]; then
    say "Space mode: the add-on in your own Zen"
    # newer than what Zen has? Zen asks you to confirm the install
    HAVE=""
    for ej in "$CFG"/zen/*/extensions.json; do
        case "$ej" in "$PROFILE"/*) continue ;; esac
        v=$(jq -r --arg id "$ADDON_ID" '[.addons[] | select(.id == $id and .active) | .version][0] // empty' "$ej" 2>/dev/null || true)
        [ -n "$v" ] && HAVE="$v"
    done
    if [ "$HAVE" != "$VER" ]; then
        echo "  Zen opens an install prompt: click Add (and allow it in private windows only if you want)."
        zen-browser "$SIGNED" >/dev/null 2>&1 &
    else
        echo "  already installed ($VER)"
    fi
    say "Space mode: the routing rule (claude-space.html -> your \"Claude\" Space)"
    if ! python3 -I "$HERE/tools/add-space-route.py"; then
        echo "  Create a Space named \"Claude\" if you haven't, quit Zen, and run:"
        echo "    python3 $HERE/tools/add-space-route.py"
    fi
    say "Space mode: the look (orange tabs, the pixel Claude on the Space row and its button)"
    python3 -I "$HERE/tools/space-chrome.py" || true
    echo "  Zen loads it at its next start."
    say "Island: Settings > Claude > Where = Claude Space (the default)"
else
    say "Claude's Zen profile in $PROFILE"
    mkdir -p "$PROFILE/extensions" "$PROFILE/chrome"
    cp "$HERE/profile/user.js" "$PROFILE/user.js"
    rm -f "$PROFILE/extensions/claudezilla@boot.industries.xpi"           # the old id
    XPI="$PROFILE/extensions/$ADDON_ID.xpi"
    if [ -n "$SIGNED" ]; then cp "$SIGNED" "$XPI"
    else (cd "$CZ/extension" && zip -qr -X "$XPI" . -x '*.DS_Store'); fi   # unsigned: allowed by user.js
    cp "$HERE"/profile/chrome/* "$PROFILE/chrome/"                        # orange tabs + the pixel Claude

    say "systemd user unit (started on demand when Claude needs the browser)"
    install -D -m 644 "$HERE/systemd/zen-claude.service" "$CFG/systemd/user/zen-claude.service"
    systemctl --user daemon-reload

    say "Hyprland: where its windows open (Settings > Claude > Opens on; default desktop 10)"
    if [ -d "$CFG/hypr/custom" ]; then
        install -m 644 "$HERE/hypr/zen-claude.lua" "$CFG/hypr/custom/zen-claude.lua"
        W="$CFG/hypr/custom/windowrules.lua"
        grep -q 'custom.zen-claude' "$W" 2>/dev/null || printf '\n-- Claude'"'"'s Zen window placement (claude-zen-sandbox)\npcall(require, "custom.zen-claude")\n' >> "$W"
        hyprctl reload >/dev/null 2>&1 || true
    fi
    # your own Zen profiles must NOT have the add-on in this mode
    for ej in "$CFG"/zen/*/extensions.json; do
        case "$ej" in "$PROFILE"/*) continue ;; esac
        if jq -e '.addons[] | select((.id == "claudezilla@boot.industries" or .id == "claude-zen@aphesist") and (.pendingUninstall | not))' "$ej" >/dev/null 2>&1; then
            echo "  WARNING: $(basename "$(dirname "$ej")") (your own Zen) has the add-on: remove it there for this mode."
        fi
    done
    say "Island: Settings > Claude > Where = Own profile"
fi
echo
echo "Done."
