hl.config({ animations = { enabled = true } })

hl.curve("out", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 2, bezier = "out" })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.8, bezier = "out", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.2, bezier = "linear", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "out" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.5, bezier = "out" })
hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "out" })

hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "out", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2, bezier = "out", style = "slidevert" })

-- quickshell animates its own panels
hl.animation({ leaf = "layers", enabled = false })
hl.animation({ leaf = "fadeLayers", enabled = false })
