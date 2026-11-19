-- Claude's Zen (claude-zen-sandbox) opens out of the way, on its own hidden
-- workspace, instead of jumping in front of you when Claude starts it.
-- Show / hide it: Settings > Claude > "Show", or
--   hyprctl dispatch 'hl.dsp.workspace.toggle_special("claude")'
hl.window_rule({
    name  = "zen-claude",
    match = { class = "^(zen-claude)$" },
    workspace = "special:claude silent",
})
