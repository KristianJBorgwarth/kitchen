local v = require("conf/vars")
local mod = v.mod

local function run(cmd) return hl.dsp.exec_cmd(cmd) end

hl.bind(mod .. " + Return", run(v.term))
hl.bind(mod .. " + W", hl.dsp.window.close())
hl.bind(mod .. " + space", run(v.menu))
hl.bind(mod .. " + B", run(v.browser))
hl.bind(mod .. " + SHIFT + S", run(v.screenshot))
hl.bind("Print", run("qs ipc call screenshot screen"))
hl.bind(mod .. " + SHIFT + Return", run(v.filemanager))
hl.bind(mod .. " + SHIFT + B", run("hyprctl reload"))
hl.bind(mod .. " + SHIFT + V", run(v.clipboard))

-- Floating windows: mod + left button moves, mod + right button resizes (sway's floating_modifier)
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Focus and move: vim keys and arrows
local dirs = {
    { "H", "Left", "left" },
    { "J", "Down", "down" },
    { "K", "Up", "up" },
    { "L", "Right", "right" },
}
for _, d in ipairs(dirs) do
    local vim, arrow, dir = d[1], d[2], d[3]
    for _, key in ipairs({ vim, arrow }) do
        hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
        hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
    end
end

-- Workspaces 1-9, plus the named m and d
for i = 1, 9 do
    hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
for _, name in ipairs({ "m", "d" }) do
    hl.bind(mod .. " + " .. name, hl.dsp.focus({ workspace = "name:" .. name }))
    hl.bind(mod .. " + SHIFT + " .. name, hl.dsp.window.move({ workspace = "name:" .. name }))
end
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Layout. Sway's `focus parent` and focus mode_toggle have no Hyprland counterpart.
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + SHIFT + space", hl.dsp.window.float({ action = "toggle" }))

-- Scratchpad
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratchpad" }))
hl.bind(mod .. " + minus", hl.dsp.workspace.toggle_special("scratchpad"))

-- Resize mode
hl.bind(mod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    local step = 10
    local resize = {
        { { "H", "Left" }, -step, 0 },
        { { "J", "Down" }, 0, step },
        { { "K", "Up" }, 0, -step },
        { { "L", "Right" }, step, 0 },
    }
    for _, r in ipairs(resize) do
        for _, key in ipairs(r[1]) do
            hl.bind(key, hl.dsp.window.resize({ x = r[2], y = r[3], relative = true }), { repeating = true })
        end
    end
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("Escape", hl.dsp.submap("reset"))
end)

-- quickshell
hl.bind(mod .. " + P", run("qs ipc call performance toggle"))
hl.bind(mod .. " + N", run("qs ipc call music toggle"))
hl.bind(mod .. " + I", run("qs ipc call keybinds toggle"))
hl.bind(mod .. " + C", run("qs ipc call controlcenter toggle"))
hl.bind(mod .. " + SHIFT + T", run("qs ipc call theme toggle"))
hl.bind(mod .. " + Tab", run("qs ipc call switcher toggle"))
hl.bind(mod .. " + SHIFT + W", run("qs ipc call wallpaper toggle"))
hl.bind(mod .. " + Z", run("qs ipc call draw toggle"))
hl.bind(mod .. " + T", run("qs ipc call pomodoro toggle"))
hl.bind(mod .. " + SHIFT + P", run("qs ipc call pomodoro startpause"))

-- Utilities (work on the lock screen too)
local locked = { locked = true }
hl.bind("XF86AudioMute", run("qs ipc call osd volumeMute"), locked)
hl.bind("XF86AudioLowerVolume", run("qs ipc call osd volumeDown"), locked)
hl.bind("XF86AudioRaiseVolume", run("qs ipc call osd volumeUp"), locked)
hl.bind("XF86AudioMicMute", run("qs ipc call osd micMute"), locked)
hl.bind("XF86MonBrightnessDown", run("qs ipc call osd brightnessDown"), locked)
hl.bind("XF86MonBrightnessUp", run("qs ipc call osd brightnessUp"), locked)
hl.bind(mod .. " + CTRL + L", run("qs ipc call lock lock"))
