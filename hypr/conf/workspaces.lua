-- Monitors are matched by description ("make model serial", what sway calls the output name).
-- Sway takes a list of outputs per workspace and falls back down it; a Hyprland rule takes one,
-- so this picks the first of each list. A workspace whose monitor is missing opens on another.
local lenovo = "desc:Lenovo Group Limited G27q-30 UMB5TWAZ"
local msi = "desc:Microstep MSI MP271 PA2T191107364"

-- kanshi (autostart) sets the actual layout; this is only the fallback
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

for _, ws in ipairs({ "1", "2", "3", "4", "5", "name:m" }) do
    hl.workspace_rule({ workspace = ws, monitor = lenovo })
end
for _, ws in ipairs({ "6", "7", "8", "9", "name:d" }) do
    hl.workspace_rule({ workspace = ws, monitor = msi })
end
