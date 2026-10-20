import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.core
import qs.core.components
import qs.services

// One notification, as a popup or a history row. Left click runs the default action,
// right click dismisses (all popups, when it is one).
Rectangle {
    id: root
    required property var notification
    property bool popup: false
    property real now: Date.now()
    readonly property bool hovered: mouse.containsMouse
    readonly property var n: notification
    readonly property color tint: n?.urgency === NotificationUrgency.Critical ? Main.theme.colRed : n?.urgency === NotificationUrgency.Low ? Main.theme.colMuted : Main.theme.colBlue
    readonly property real progress: Number(n?.hints?.value ?? -1)

    implicitHeight: body.implicitHeight + 28
    radius: Main.radius
    color: popup ? Main.theme.colBg : (hovered ? Qt.lighter(Main.theme.colSurface, 1.2) : Main.theme.colSurface)
    border.color: popup ? Main.theme.colMuted : Main.theme.overlay(0.05)
    border.width: 1

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => {
            if (event.button === Qt.RightButton && root.popup)
                Notifs.popups = [];
            else if (event.button === Qt.RightButton)
                Notifs.dismiss(root.n);
            else
                Notifs.activate(root.n);
        }
    }

    // urgency edge
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height - 24
        radius: 2
        color: root.tint
    }

    Row {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        anchors.leftMargin: 18
        spacing: 12

        // the notification's own image (album art, avatar…) beats the app icon. Either can
        // fail to load (browsers delete their temp files), so fall through to the bell
        Item {
            width: 36
            height: 36
            ClippingRectangle {
                anchors.fill: parent
                visible: picture.status === Image.Ready
                radius: Main.radius
                color: "transparent"
                Image {
                    id: picture
                    anchors.fill: parent
                    source: root.n ? Notifs.image(root.n) : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 72
                    sourceSize.height: 72
                    asynchronous: true
                }
            }
            IconImage {
                id: appIcon
                anchors.centerIn: parent
                visible: picture.status !== Image.Ready && status === Image.Ready
                implicitSize: 28
                source: root.n ? Notifs.icon(root.n) : ""
            }
            Text {
                anchors.centerIn: parent
                visible: picture.status !== Image.Ready && appIcon.status !== Image.Ready
                text: "󰂚"
                color: root.tint
                font: Main.iconFont
            }
        }

        Column {
            width: parent.width - 48
            spacing: 4

            Item {
                width: parent.width
                height: appLine.implicitHeight
                Text {
                    id: appLine
                    anchors.left: parent.left
                    anchors.right: close.left
                    anchors.rightMargin: 6
                    text: (root.n?.appName || "Notification") + "  ·  " + (root.n ? Notifs.ago(root.n, root.now) : "")
                    color: Main.theme.colAccentMid
                    font: Main.smallFont
                    elide: Text.ElideRight
                }
                Text {
                    id: close
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: root.hovered ? 1 : 0.35
                    text: "󰅖"
                    color: Main.theme.colFg
                    font: Main.smallFont
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dismiss(root.n)
                    }
                }
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.n?.summary ?? ""
                color: Main.theme.colFg
                font.family: Main.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.n?.body ?? ""
                textFormat: Text.StyledText
                color: Main.theme.colAccentLight
                linkColor: Main.theme.colBlue
                font: Main.barFont
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 4 : 3
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            // apps like downloads or volume report progress in the `value` hint
            Rectangle {
                visible: root.progress >= 0
                width: parent.width
                height: 4
                radius: 2
                color: Main.theme.colMuted
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.progress / 100))
                    height: parent.height
                    radius: 2
                    color: root.tint
                }
            }

            Flow {
                width: parent.width
                spacing: 6
                topPadding: 4
                visible: actions.count > 0
                Repeater {
                    id: actions
                    model: (root.n?.actions ?? []).filter(a => a.identifier !== "default")
                    Chip {
                        required property var modelData
                        text: modelData.text
                        clickable: true
                        onClicked: {
                            modelData.invoke();
                            if (!root.n.resident)
                                Notifs.dismiss(root.n);
                        }
                    }
                }
            }
        }
    }
}
