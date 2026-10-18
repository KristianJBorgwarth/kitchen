pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Media — the MPRIS player worth showing: playing one first, else the first one
Singleton {
    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null
}
