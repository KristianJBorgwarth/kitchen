pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Network — NetworkManager state (wired + wifi). `scanning` turns the wifi scanner on
// while the control center's network tab is visible.
Singleton {
    id: root
    property bool scanning: false

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var activeDevice: devices.find(d => d.connected) ?? null

    readonly property bool hasWifi: wifiDevice !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool connected: activeDevice !== null
    readonly property bool wired: activeDevice?.type === DeviceType.Wired

    // connected first, then saved, then by signal
    readonly property var wifiNetworks: !wifiDevice ? [] : wifiDevice.networks.values.filter(n => n.name).sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))

    readonly property string label: {
        if (!activeDevice)
            return "Disconnected";
        if (wired)
            return "Wired";
        return activeDevice.networks.values.find(n => n.connected)?.name ?? "Wi-Fi";
    }

    Binding {
        when: root.wifiDevice !== null
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.scanning && root.wifiEnabled
    }

    function toggleWifi(): void {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }
}
