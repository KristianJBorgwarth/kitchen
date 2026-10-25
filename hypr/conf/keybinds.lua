local v = require("conf/vars")
local mod = v.mod

-- Every bind is described as "Section|Description", or "Section|Description|program" for an
-- app's icon: quickshell's keybind cheatsheet reads them back from `hyprctl binds`
local section = "General"
local function bind(keys, action, desc, opts)
  opts = opts or {}
  opts.description = section .. "|" .. desc
  hl.bind(keys, action, opts)
end
local function run(cmd) return hl.dsp.exec_cmd(cmd) end
local function launch(keys, cmd, desc) bind(keys, run(cmd), desc .. "|" .. cmd:match("^%S+")) end

section = "Apps"
launch(mod .. " + Return", v.term, "Terminal")
bind(mod .. " + W", hl.dsp.window.close(), "Close window")
bind(mod .. " + space", run(v.menu), "App launcher")
launch(mod .. " + B", v.browser, "Browser")
bind(mod .. " + SHIFT + S", run(v.screenshot), "Screenshot")
bind("Print", run("qs ipc call screenshot screen"), "Screenshot whole screen")
launch(mod .. " + SHIFT + Return", v.filemanager, "File manager")
bind(mod .. " + SHIFT + B", run("hyprctl reload && notify-send -a Hyprland -t 1500 'Config reloaded'"), "Reload Hyprland")
bind(mod .. " + SHIFT + V", run(v.clipboard), "Clipboard history")

-- mod + left button moves, mod + right button resizes
section = "Floating windows"
bind(mod .. " + mouse:272", hl.dsp.window.drag(), "Move window", { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), "Resize window", { mouse = true })

-- vim keys and arrows
section = "Focus and move"
local dirs = {
  { "H", "Left",  "left" },
  { "J", "Down",  "down" },
  { "K", "Up",    "up" },
  { "L", "Right", "right" },
}
for _, d in ipairs(dirs) do
  local vim, arrow, dir = d[1], d[2], d[3]
  for _, key in ipairs({ vim, arrow }) do
    bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }), "Focus " .. dir)
    bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }), "Move window " .. dir)
  end
end

-- 1-9, plus the named m and d
section = "Workspaces"
for i = 1, 9 do
  bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }), "Workspace " .. i)
  bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), "Move window to workspace " .. i)
end
for _, name in ipairs({ "m", "d" }) do
  bind(mod .. " + " .. name, hl.dsp.focus({ workspace = "name:" .. name }), "Workspace " .. name)
  bind(mod .. " + SHIFT + " .. name, hl.dsp.window.move({ workspace = "name:" .. name }),
    "Move window to workspace " .. name)
end
bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }), "Move window to workspace 10")

section = "Layout"
bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), "Fullscreen")
-- a floated window gets 60% x 65% of the monitor, centered, instead of its tiled size
local function toggle_float()
  hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
  local w, m = hl.get_active_window(), hl.get_active_monitor()
  if not (w and w.floating and m) then return end
  local mw, mh = m.width / m.scale, m.height / m.scale
  if m.transform % 2 == 1 then mw, mh = mh, mw end
  hl.dispatch(hl.dsp.window.resize({ x = math.floor(mw * 0.6), y = math.floor(mh * 0.65) }))
  hl.dispatch(hl.dsp.window.center())
end
bind(mod .. " + SHIFT + space", toggle_float, "Toggle floating")

section = "Scratchpad"
bind(mod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratchpad" }), "Send to scratchpad")
bind(mod .. " + minus", hl.dsp.workspace.toggle_special("scratchpad"), "Show scratchpad")

section = "Resize mode"
bind(mod .. " + R", hl.dsp.submap("resize"), "Resize mode")
hl.define_submap("resize", function()
  local step = 10
  local resize = {
    { { "H", "Left" },  -step, 0,     "Shrink width" },
    { { "J", "Down" },  0,     step,  "Grow height" },
    { { "K", "Up" },    0,     -step, "Shrink height" },
    { { "L", "Right" }, step,  0,     "Grow width" },
  }
  for _, r in ipairs(resize) do
    for _, key in ipairs(r[1]) do
      bind(key, hl.dsp.window.resize({ x = r[2], y = r[3], relative = true }), r[4], { repeating = true })
    end
  end
  bind("Return", hl.dsp.submap("reset"), "Leave mode")
  bind("Escape", hl.dsp.submap("reset"), "Leave mode")
end)

section = "Quickshell"
bind(mod .. " + P", run("qs ipc call performance toggle"), "System monitor")
bind(mod .. " + N", run("qs ipc call music toggle"), "Music player")
bind(mod .. " + I", run("qs ipc call keybinds toggle"), "Keybinds")
bind(mod .. " + C", run("qs ipc call controlcenter toggle"), "Control center")
bind(mod .. " + SHIFT + T", run("qs ipc call theme toggle"), "Dark / light mode")
bind(mod .. " + Tab", run("qs ipc call switcher toggle"), "Workspace switcher")
bind(mod .. " + SHIFT + W", run("qs ipc call wallpaper toggle"), "Wallpaper picker")
bind(mod .. " + Z", run("qs ipc call draw toggle"), "Draw on screen")
bind(mod .. " + T", run("qs ipc call pomodoro toggle"), "Pomodoro")
bind(mod .. " + SHIFT + P", run("qs ipc call pomodoro startpause"), "Pomodoro start / pause")

section = "Utilities"
local function locked() return { locked = true } end
bind("XF86AudioMute", run("qs ipc call osd volumeMute"), "Volume mute", locked())
bind("XF86AudioLowerVolume", run("qs ipc call osd volumeDown"), "Volume down", locked())
bind("XF86AudioRaiseVolume", run("qs ipc call osd volumeUp"), "Volume up", locked())
bind("XF86AudioMicMute", run("qs ipc call osd micMute"), "Mic mute", locked())
bind("XF86MonBrightnessDown", run("qs ipc call osd brightnessDown"), "Brightness down", locked())
bind("XF86MonBrightnessUp", run("qs ipc call osd brightnessUp"), "Brightness up", locked())
bind(mod .. " + CTRL + L", run("qs ipc call lock lock"), "Lock screen")
