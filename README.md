# claude-zen-sandbox

A separate Zen browser profile that only Claude drives, through
[Claudezilla](https://github.com/boot-industries/claudezilla). Your own Zen never
gets the add-on, so its tabs, Spaces, history, cookies and saved logins are out
of Claude's reach, whatever the add-on can do.

Why not a Zen Space? Spaces (and Firefox containers) only group tabs inside one
profile. The add-on sees every tab in its profile, can list them and take one
over; its "ownership" rule only keeps agents off each other's tabs, not yours.
A profile is the real boundary.

## What it sets up

- Claudezilla's native host and MCP server, pinned (`CZ_TAG`, default v0.7.7), in
  `~/.local/share/claudezilla`; npm dependencies installed with `--ignore-scripts`.
- The native-messaging file in `/usr/lib/mozilla/native-messaging-hosts/`
  (root, via pkexec). Zen 1.24 reads native-messaging files only from there:
  not from `~/.config/zen` or `~/.config/mozilla`. `~/.mozilla` would also work,
  but creating it can make Firefox switch back to its old profile folder.
- A Zen profile in `~/.config/zen/claude` (not in Zen's profile list), with the
  signed add-on from addons.mozilla.org placed in its `extensions/` and
  [`profile/user.js`](profile/user.js): add-on loads without a prompt, no password
  manager or form autofill, blank start, the red accent.
- `zen-claude.service` (systemd user unit): runs that profile as its own instance
  (`--no-remote --name zen-claude`), so it never takes your links, and quits it
  cleanly on stop.
- A Hyprland rule (Lua config) for where its windows open, without ever taking
  focus: its own desktop, workspace 10 (default, so you can watch it work), a
  hidden special workspace, or wherever you are. Set in the island (Settings >
  Claude > Opens on, `claudeBrowserPlace` in Panacea's settings.json).

## Install

```sh
./install.sh
```

Then remove Claudezilla from your own Zen if it is there (about:addons >
Claudezilla > Remove). The installer warns if any other Zen profile still has it.

## With Panacea's island chat

[panacea-claude-bridge](https://github.com/aphesist/panacea-claude-bridge) gives
the island's Claude the Claudezilla tools and sets `CLAUDEZILLA_AUTOSTART_CMD`, so
Claude's Zen starts by itself the first time it's needed. Settings > Claude in the
island (from [panacea-config](https://github.com/aphesist/panacea-config)):
browser on/off, what needs an Allow card, auto-start, connection status, and a
button to show or hide its window.

Plain Claude Code works too:

```sh
claude mcp add --scope user claudezilla \
  -e 'CLAUDEZILLA_AUTOSTART_CMD=["systemctl","--user","start","zen-claude.service"]' \
  -- node ~/.local/share/claudezilla/mcp/server.js --tools all
```

## Use

- Watch it: go to desktop 10 (Super+0). When set to hidden:
  `hyprctl dispatch 'hl.dsp.workspace.toggle_special("claude")'`
- Sign in to a site for Claude: log in in its window by hand (for WhatsApp Web,
  scan the QR code with your phone). Only what you log into in this profile is
  ever available to it.
- Start / stop by hand: `systemctl --user start|stop zen-claude`

## Undo

```sh
systemctl --user stop zen-claude
rm ~/.config/systemd/user/zen-claude.service && systemctl --user daemon-reload
rm -r ~/.config/zen/claude ~/.local/share/claudezilla
pkexec rm /usr/lib/mozilla/native-messaging-hosts/claudezilla.json
rm ~/.config/hypr/custom/zen-claude.lua   # and its pcall line in custom/windowrules.lua
```

MIT licensed. Claudezilla itself is MIT, by Boot Industries.
