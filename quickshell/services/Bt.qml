pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var connectedDevices: adapter ? adapter.devices.values.filter(d => d.connected) : []
    // unnamed devices only have an address, not worth listing
    readonly property var devices: adapter ? adapter.devices.values.filter(d => d.name && d.name !== d.address).sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name)) : []
    readonly property bool scanning: adapter?.discovering ?? false

    readonly property string label: {
        if (!enabled)
            return "Off";
        if (connectedDevices.length === 0)
            return "On";
        if (connectedDevices.length === 1)
            return connectedDevices[0].name;
        return connectedDevices.length + " devices";
    }

    function toggleScan(): void {
        if (adapter?.enabled)
            adapter.discovering = !adapter.discovering;
    }

    function toggle(): void {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }
}
