import QtQuick
import qs.core
import qs.core.components

// A flat section: a divider, a small caps title, then the content.
Item {
    id: root
    property string title: ""
    property string icon: ""
    property string detail: ""
    // content that can't be narrowed to a single process fades out
    property bool unavailable: false
    default property alias content: body.data

    Divider {
        width: parent.width
    }

    SectionLabel {
        id: titleText
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: 12
        text: (root.icon ? root.icon + "  " : "") + root.title
    }

    Text {
        anchors.right: parent.right
        anchors.left: titleText.right
        anchors.leftMargin: 12
        anchors.baseline: titleText.baseline
        horizontalAlignment: Text.AlignRight
        text: root.detail
        color: Main.theme.colAccentDark
        font: Main.smallFont
        elide: Text.ElideLeft
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.topMargin: 36
        opacity: root.unavailable ? 0.12 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }

    Text {
        visible: root.unavailable
        anchors.centerIn: parent
        text: "not tracked per process"
        color: Main.theme.colAccentDark
        font: Main.smallFont
    }
}
