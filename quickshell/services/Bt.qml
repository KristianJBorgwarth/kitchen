pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bt — BlueZ default adapter; available is false on machines without one
Singleton {
    id: root
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var connectedDevices: adapter ? adapter.devices.values.filter(d => d.connected) : []

    readonly property string label: {
        if (!enabled)
            return "Off";
        if (connectedDevices.length === 0)
            return "On";
        if (connectedDevices.length === 1)
            return connectedDevices[0].name;
        return connectedDevices.length + " devices";
    }

    function toggle(): void {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }
}
