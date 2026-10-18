pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Network — NetworkManager state (wired + wifi)
Singleton {
    id: root
    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var activeDevice: devices.find(d => d.connected) ?? null

    readonly property bool hasWifi: wifiDevice !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool connected: activeDevice !== null
    readonly property bool wired: activeDevice?.type === DeviceType.Wired

    readonly property string label: {
        if (!activeDevice)
            return "Disconnected";
        if (wired)
            return "Wired";
        return activeDevice.networks.values.find(n => n.connected)?.name ?? "Wi-Fi";
    }

    function toggleWifi(): void {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }
}
