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
XPI_URL="https://addons.mozilla.org/firefox/downloads/latest/claudezilla/latest.xpi"
SYS_MANIFEST=/usr/lib/mozilla/native-messaging-hosts/claudezilla.json
say() { printf '\n== %s\n' "$*"; }

for c in git node npm curl zen-browser systemctl; do
    command -v "$c" >/dev/null || { echo "missing: $c"; exit 1; }
done

say "Claudezilla $CZ_TAG (native host + MCP server) in $CZ"
if [ -d "$CZ/.git" ]; then
    git -C "$CZ" fetch -q --depth 1 origin tag "$CZ_TAG"
    git -C "$CZ" -c advice.detachedHead=false checkout -q "$CZ_TAG"
else
    git clone -q --depth 1 --branch "$CZ_TAG" https://github.com/boot-industries/claudezilla.git "$CZ"
fi
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
XPI="$PROFILE/extensions/claudezilla@boot.industries.xpi"
if [ ! -s "$XPI" ]; then
    curl -fsSL --proto '=https' -o "$TMP/claudezilla.xpi" "$XPI_URL"
    unzip -tq "$TMP/claudezilla.xpi" >/dev/null       # a real add-on, not an error page
    cp "$TMP/claudezilla.xpi" "$XPI"
fi

say "systemd user unit (started on demand when Claude needs the browser)"
install -D -m 644 "$HERE/systemd/zen-claude.service" "$CFG/systemd/user/zen-claude.service"
systemctl --user daemon-reload

say "Hyprland: its windows open on a hidden workspace (special:claude)"
if [ -d "$CFG/hypr/custom" ]; then
    install -m 644 "$HERE/hypr/zen-claude.lua" "$CFG/hypr/custom/zen-claude.lua"
    W="$CFG/hypr/custom/windowrules.lua"
    grep -q 'custom.zen-claude' "$W" 2>/dev/null || printf '\n-- Claude'"'"'s Zen on its own hidden workspace (claude-zen-sandbox)\npcall(require, "custom.zen-claude")\n' >> "$W"
    hyprctl reload >/dev/null 2>&1 || true
fi

# Your own Zen profiles must NOT have the add-on: warn if one still does.
for ej in "$CFG"/zen/*/extensions.json; do
    case "$ej" in "$PROFILE"/*) continue ;; esac
    if grep -q '"id":"claudezilla@boot.industries"' "$ej" 2>/dev/null; then
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
