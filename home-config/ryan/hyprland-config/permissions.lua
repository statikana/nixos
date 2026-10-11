print("permissions.lua")

hl.permission("/usr/(bin|local/bin)/hyprshot", "screencopy", "allow")

hl.config({
    ecosystem = {
        enforce_permissions = true,
    },
})
