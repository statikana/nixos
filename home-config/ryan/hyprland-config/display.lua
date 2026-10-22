print("display.lua")

-- 165Hz costs real battery for no benefit during normal desktop use, so only
-- run full-rate on AC; refresh-rate-listener.sh calls `hyprctl reload` (which
-- re-evaluates this file) whenever AC is plugged/unplugged
local function onAC()
    local f = io.open("/sys/class/power_supply/AC/online", "r")
    if not f then return true end
    local v = f:read("*l")
    f:close()
    return v == "1"
end

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1.25",
})

-- internal laptop panel only -- external monitors keep "preferred" above
hl.monitor({
    output   = "eDP-1",
    mode     = onAC() and "2560x1600@165.02" or "2560x1600@60.01",
    position = "auto",
    scale    = "1.25",
})

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
