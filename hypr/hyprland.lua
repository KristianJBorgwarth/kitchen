-- Hyprland config (Lua, Hyprland >= 0.55). Mirrors sway/: same keys, same quickshell IPC.
-- Sway keeps working as the other session; compositor-specific bits live in quickshell's Compositor.

require("conf/vars")
require("conf/input")
require("conf/appearance")
require("conf/colors")
require("conf/workspaces")
require("conf/keybinds")
require("conf/autostart")
