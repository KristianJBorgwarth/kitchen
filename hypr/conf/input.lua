hl.config({
    input = {
        kb_layout = "dk",
        kb_variant = "nodeadkeys",
        kb_options = "lv3:caps_switch",

        follow_mouse = 1,

        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

hl.gesture({
    fingers = 3,
    direction = "vertical",
    action = function()
        hl.exec_cmd("qs ipc call switcher toggle")
    end,
})

hl.gesture({ fingers = 2, direction = "pinchout", action = "fullscreen" })
