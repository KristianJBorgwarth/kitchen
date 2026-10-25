-- window border colors come from the quickshell palette: conf/colors.lua (generated)
local monitors = require("conf/vars").monitors

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 5,
        border_size = 2,
        layout = "dwindle",
    },

    -- same radius as quickshell's Main.radius
    decoration = {
        rounding = 8,
        shadow = { enabled = false },
        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            new_optimizations = true,
            ignore_opacity = true,
        },
    },

    dwindle = { preserve_split = true },

    -- the current workspace's key jumps back to the previous one
    binds = { workspace_back_and_forth = true },

    misc = {
        -- reload with mod+shift+b only: autoreload fires mid-save and breaks the requires
        disable_autoreload = true,
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
})

-- Floating windows. Wayland has no window_role/window_type, so only the title rules carry over.
for _, title in ipairs({ "Preferences", "win.*", "System Performance" }) do
    hl.window_rule({ match = { title = title }, float = true })
end

-- JetBrains project/welcome pickers report the same class as a real project window and set no
-- other hint, so title is the only thing that tells them apart.
--
-- DataGrip reuses the *same* window surface for its welcome picker and the opened project (the
-- title just changes in place), so floating it here would stick for the whole session. Rider
-- opens a separate window per project, so its picker can be floated safely.
hl.window_rule({
    match = { class = "jetbrains-rider", title = "Welcome to JetBrains Rider" },
    float = true,
})

hl.window_rule({ match = { class = "code-oss" }, opacity = "0.85" })

-- Toolbox places itself off-screen; put it under the tray. It also re-requests its own position
-- after mapping, so those X11 configure requests are ignored to keep the move. The monitor is a
-- separate rule so a missing external display doesn't stop the move from applying.
hl.window_rule({
    match = { class = "jetbrains-toolbox" },
    float = true,
    no_anim = true,
    suppress_event = "x11configurerequest",
    move = "(monitor_w-window_w-8) 42",
})
hl.window_rule({ match = { class = "jetbrains-toolbox" }, monitor = monitors.lenovo })
