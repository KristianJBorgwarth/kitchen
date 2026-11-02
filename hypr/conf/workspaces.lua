local monitors = require("conf/vars").monitors

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

local setups = {
  { monitors.lenovo, monitors.msi },
  { monitors.officeLeft, monitors.officeRight },
}
local groups = {
  { "1", "2", "3", "4", "5", "name:m" },
  { "6", "7", "8", "9", "name:d" },
}

local function connected()
  local present = {}
  for _, m in ipairs(hl.get_monitors()) do
    present["desc:" .. m.description] = true
  end
  return present
end

local function apply()
  local present = connected()
  for _, setup in ipairs(setups) do
    if present[setup[1]] and present[setup[2]] then
      for i, ws_list in ipairs(groups) do
        for _, ws in ipairs(ws_list) do
          hl.workspace_rule({ workspace = ws, monitor = setup[i] })
        end
      end
      return
    end
  end
end

apply()
hl.on("monitor.added", apply)
hl.on("monitor.removed", apply)
