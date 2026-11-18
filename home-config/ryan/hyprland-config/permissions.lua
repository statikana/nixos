print("permissions.lua")

hl.permission({ binary = ".*/grim$", type = "screencopy", mode = "allow" })
hl.permission({ binary = ".*/hyprpicker$", type = "screencopy", mode = "allow" })
hl.permission({ binary = ".*/\\.xdg-desktop-portal-hyprland-wrapped$", type = "screencopy", mode = "allow" })

hl.config({
    ecosystem = {
        enforce_permissions = true,
    },
})
