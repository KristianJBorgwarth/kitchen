local monitors = require("conf/vars").monitors
local lenovo, msi = monitors.lenovo, monitors.msi
local right, left = monitors.officeRight, monitors.officeLeft

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

for _, ws in ipairs({ "1", "2", "3", "4", "5", "name:m" }) do
  hl.workspace_rule({ workspace = ws, monitor = lenovo })
end
for _, ws in ipairs({ "6", "7", "8", "9", "name:d" }) do
  hl.workspace_rule({ workspace = ws, monitor = msi })
end

for _, ws in ipairs({ "6", "7", "8", "9", "name:d" }) do
  hl.workspace_rule({ workspace = ws, monitor = right })
end

for _, ws in ipairs({ "1", "2", "3", "4", "5", "name:m" }) do
  hl.workspace_rule({ workspace = ws, monitor = left })
end
