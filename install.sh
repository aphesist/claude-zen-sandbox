#!/bin/bash
# claude-zen-sandbox: a separate Zen profile that only Claude drives (Claudezilla).
# Your own Zen profile never gets the add-on, so its tabs, history, cookies and
# logins are out of Claude's reach. Safe to re-run (it updates in place).
#
#   ./install.sh            install / update
#
# Root is needed once, for the native-messaging file Zen reads (pkexec).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CZ_TAG="${CZ_TAG:-v0.7.7}"                                  # Claudezilla version (host + MCP server)
CZ="${XDG_DATA_HOME:-$HOME/.local/share}/claudezilla"
PROFILE="$HOME/.config/zen/claude"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
SYS_MANIFEST=/usr/lib/mozilla/native-messaging-hosts/claudezilla.json
say() { printf '\n== %s\n' "$*"; }

for c in git node npm jq zip zen-browser systemctl; do
    command -v "$c" >/dev/null || { echo "missing: $c"; exit 1; }
done

say "Claudezilla $CZ_TAG (native host + MCP server) in $CZ"
if [ -d "$CZ/.git" ]; then
    git -C "$CZ" fetch -q --depth 1 origin tag "$CZ_TAG"
    git -C "$CZ" -c advice.detachedHead=false checkout -q "$CZ_TAG"
else
    git clone -q --depth 1 --branch "$CZ_TAG" https://github.com/boot-industries/claudezilla.git "$CZ"
fi
# our changes on top (patches/): a fixed agent id and kept tabs, so one client's
# short sessions (the island runs one per message) share the same tabs
git -C "$CZ" checkout -q -- . 2>/dev/null || true
for p in "$HERE"/patches/*.patch; do git -C "$CZ" apply "$p"; done
# its dependencies, without running any package install scripts
(cd "$CZ/mcp" && npm install --quiet --ignore-scripts --no-audit --no-fund)
printf '#!/bin/bash\nexec %s "%s/host/index.js" "$@"\n' "$(command -v node)" "$CZ" > "$CZ/host/run.sh"
chmod 755 "$CZ/host/run.sh" "$CZ/host/index.js"

say "Native-messaging file (Zen only reads the system-wide folder)"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
sed "s|@HOST@|$CZ/host/run.sh|" "$HERE/native/claudezilla.json.in" > "$TMP/claudezilla.json"
if ! cmp -s "$TMP/claudezilla.json" "$SYS_MANIFEST" 2>/dev/null; then
    pkexec install -D -m 644 "$TMP/claudezilla.json" "$SYS_MANIFEST"
fi
# per-user copies that Zen ignores, left over from earlier attempts
rm -f "$CFG/zen/native-messaging-hosts/claudezilla.json" "$CFG/mozilla/native-messaging-hosts/claudezilla.json"

say "Claude's Zen profile in $PROFILE"
mkdir -p "$PROFILE/extensions"
cp "$HERE/profile/user.js" "$PROFILE/user.js"
# our build of the add-on (patches/0002: orange look, no tab group, the pixel Claude's
# mood signal), from the same pinned source as the host; unsigned, allowed in user.js
XPI="$PROFILE/extensions/claudezilla@boot.industries.xpi"
(cd "$CZ/extension" && rm -f "$TMP/claudezilla.xpi" && zip -qr -X "$TMP/claudezilla.xpi" . -x '*.DS_Store')
cmp -s "$TMP/claudezilla.xpi" "$XPI" || cp "$TMP/claudezilla.xpi" "$XPI"
# the orange tabs and the pixel Claude above them (userChrome.css + critter-*.svg)
mkdir -p "$PROFILE/chrome"
cp "$HERE"/profile/chrome/* "$PROFILE/chrome/"

say "systemd user unit (started on demand when Claude needs the browser)"
install -D -m 644 "$HERE/systemd/zen-claude.service" "$CFG/systemd/user/zen-claude.service"
systemctl --user daemon-reload

say "Hyprland: where its windows open (Settings > Claude > Opens on; default desktop 10)"
if [ -d "$CFG/hypr/custom" ]; then
    install -m 644 "$HERE/hypr/zen-claude.lua" "$CFG/hypr/custom/zen-claude.lua"
    W="$CFG/hypr/custom/windowrules.lua"
    grep -q 'custom.zen-claude' "$W" 2>/dev/null || printf '\n-- Claude'"'"'s Zen on its own hidden workspace (claude-zen-sandbox)\npcall(require, "custom.zen-claude")\n' >> "$W"
    hyprctl reload >/dev/null 2>&1 || true
fi

# Your own Zen profiles must NOT have the add-on: warn if one still does.
for ej in "$CFG"/zen/*/extensions.json; do
    case "$ej" in "$PROFILE"/*) continue ;; esac
    # (one removed in about:addons stays listed as pendingUninstall until Zen restarts: that's fine)
    if jq -e '.addons[] | select(.id == "claudezilla@boot.industries" and (.pendingUninstall | not))' "$ej" >/dev/null 2>&1; then
        echo
        echo "  WARNING: $(basename "$(dirname "$ej")") (your own Zen) still has Claudezilla."
        echo "  Remove it there (about:addons > Claudezilla > Remove): only Claude's profile should have it."
    fi
done

cat <<EOF

Done. Try it:   systemctl --user start zen-claude
Panacea's island chat (panacea-claude-bridge) starts it by itself the first time Claude
uses the browser; see Settings > Claude in the island.
EOF
