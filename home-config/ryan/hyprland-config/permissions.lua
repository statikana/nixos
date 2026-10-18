print("permissions.lua")

hl.permission({ binary = "${lib.getExe pkgs.grim}", type = "screencopy", mode = "allow" })

hl.config({
    ecosystem = {
        enforce_permissions = true,
    },
})

