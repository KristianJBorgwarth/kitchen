return {
    mod = "SUPER",
    -- GTK 4.24 sends an empty blur region and Hyprland then skips blur (hyprwm/Hyprland#16508)
    term = "GDK_WAYLAND_DISABLE=ext_background_effect_manager_v1 ghostty",
    browser = "brave",
    menu = "qs ipc call launcher toggle",
    screenshot = "qs ipc call screenshot start",
    filemanager = "thunar",
    clipboard = "qs ipc call clipboard toggle",
    monitors = {
        lenovo = "desc:Lenovo Group Limited G27q-30 UMB5TWAZ",
        msi = "desc:Microstep MSI MP271 PA2T191107364",
        officeLeft = "desc:HP Inc. HP 527pu CNC51706GJ",
        officeRight = "desc:HP Inc. HP 527pu CNC5170681",
    },
}
