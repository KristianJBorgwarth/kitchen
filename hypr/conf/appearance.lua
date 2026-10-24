-- window border colors come from the quickshell palette: conf/colors.lua (generated)

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 2,
        border_size = 2,
        layout = "dwindle",
    },

    -- plain and flat
    decoration = {
        rounding = 0,
        shadow = { enabled = false },
        blur = { enabled = false },
    },

    animations = { enabled = false },

    dwindle = { preserve_split = true },

    -- the current workspace's key jumps back to the previous one
    binds = { workspace_back_and_forth = true },

    misc = {
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
