print("programs.lua")

hl.on("hyprland.start", function ()
    hl.exec_cmd("waybar")
    hl.exec_cmd("firefox")

    -- have cliphist watch wlcliphist
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
end)