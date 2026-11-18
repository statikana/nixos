print("programs.lua")

hl.on("hyprland.start", function ()
    hl.exec_cmd("waybar")
    hl.exec_cmd("firefox")

    -- have cliphist watch text & image clipboard selections
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
