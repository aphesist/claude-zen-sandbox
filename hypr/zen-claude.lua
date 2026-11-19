-- Where Claude's Zen (claude-zen-sandbox) opens. Set in the island:
-- Settings > Claude > "Opens on" (settings.json: claudeBrowserPlace), which
-- reloads Hyprland so this file reads it again.
--   desktop  its own desktop, workspace 10 (Super+0): watch it work there   (default)
--   hidden   a hidden special workspace; show it with
--            hyprctl dispatch 'hl.dsp.workspace.toggle_special("claude")'
--   current  wherever you are, like any other window
-- It never steals focus ("silent"): you go and look when you want to.
local CLAUDE_DESKTOP = "10"

local place = "desktop"
local f = io.open(os.getenv("HOME") .. "/.config/panacea/settings.json", "r")
if f then
    local s = f:read("a") or ""
    f:close()
    place = s:match('"claudeBrowserPlace"%s*:%s*"(%a+)"') or place
end

local ws = ({ desktop = CLAUDE_DESKTOP .. " silent", hidden = "special:claude silent" })[place]
if ws then
    hl.window_rule({
        name  = "zen-claude",
        match = { class = "^(zen-claude)$" },
        workspace = ws,
    })
end
