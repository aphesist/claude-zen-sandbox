#!/bin/bash
# Save your addons.mozilla.org API key for signing Claude's add-on build.
# Get one at https://addons.mozilla.org/developers/addon/api/key/
# Stored in ~/.config/claude-zen-sandbox/amo.env (only you can read it).
set -eu
DIR="$HOME/.config/claude-zen-sandbox"
F="$DIR/amo.env"
install -d -m 700 "$DIR"
echo "addons.mozilla.org API key for claude-zen-sandbox"
echo "(from https://addons.mozilla.org/developers/addon/api/key/)"
echo
read -r -p 'JWT issuer (starts with user:): ' ISSUER
read -r -s -p 'JWT secret (hidden while you type): ' SECRET
echo
case "$ISSUER" in user:*) ;; *) echo "That issuer doesn't start with 'user:'. Nothing saved."; read -r -p 'Enter to close'; exit 1 ;; esac
[ -n "$SECRET" ] || { echo "Empty secret. Nothing saved."; read -r -p 'Enter to close'; exit 1; }
umask 077
printf 'AMO_JWT_ISSUER=%s\nAMO_JWT_SECRET=%s\n' "$ISSUER" "$SECRET" > "$F"
chmod 600 "$F"
echo "Saved to $F"
read -r -p 'Enter to close'
