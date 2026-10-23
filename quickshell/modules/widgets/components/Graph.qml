import QtQuick
import qs.core

// Samples are placed by their timestamp in `times`, so uneven sample rates plot to scale.
Canvas {
    id: root
    // repainted 5x/s while the monitor is open; rasterize on the GPU
    renderTarget: Canvas.FramebufferObject
    property var values: []
    property var values2: []
    property real max: 100 // 0 = scale to the data
    property var times: []
    property real window: 60000 // ms across the full width
    property color color: Main.theme.colFg
    property color color2: Main.theme.colAccentMid
    property var format: v => Math.round(v) + "%"
    property string label: ""   // prefix for the first series in the hover bubble
    property string label2: ""
    property bool showPeak: true

    readonly property bool hovering: hover.hovered
    readonly property real hoverX: hover.point.position.x
    readonly property int hoverIndex: {
        const n = Math.min(values.length, times.length);
        if (!hovering || n < 1)
            return -1;
        const t = times.slice(times.length - n);
        const target = t[n - 1] - (width - hoverX) / width * window;
        let best = -1, bd = Infinity;
        for (let i = 0; i < n; i++) {
            const d = Math.abs(t[i] - target);
            if (d < bd) {
                bd = d;
                best = i;
            }
        }
        return best;
    }
    readonly property real peak: {
        let m = 0;
        for (const v of values)
            if (v > m)
                m = v;
        for (const v of values2)
            if (v > m)
                m = v;
        return m;
    }

    readonly property real scaleMax: max > 0 ? max : Math.max(1, ...values, ...values2) * 1.2

    onHoverXChanged: if (hovering) requestPaint()
    onHoveringChanged: requestPaint()
    onValuesChanged: requestPaint()
    onValues2Changed: requestPaint()
    onTimesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function series(ctx, data, col, fillAlpha) {
        const n = Math.min(data.length, times.length);
        if (n < 2)
            return;
        data = data.slice(data.length - n);
        const t = times.slice(times.length - n);
        const now = t[n - 1];
        const x = i => width - (now - t[i]) / window * width;
        const y = v => height - 1.5 - Math.min(1, Math.max(0, v / scaleMax)) * (height - 3);

        ctx.beginPath();
        ctx.moveTo(x(0), y(data[0]));
        for (let i = 1; i < data.length; i++) {
            const xm = (x(i - 1) + x(i)) / 2;
            ctx.bezierCurveTo(xm, y(data[i - 1]), xm, y(data[i]), x(i), y(data[i]));
        }
        ctx.lineWidth = 1.5;
        ctx.strokeStyle = col;
        ctx.stroke();

        ctx.lineTo(x(data.length - 1), height);
        ctx.lineTo(x(0), height);
        ctx.closePath();
        const g = ctx.createLinearGradient(0, 0, 0, height);
        g.addColorStop(0, Qt.rgba(col.r, col.g, col.b, fillAlpha));
        g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0));
        ctx.fillStyle = g;
        ctx.fill();

        ctx.beginPath();
        ctx.arc(x(data.length - 1) - 2, y(data[data.length - 1]), 2.5, 0, 2 * Math.PI);
        ctx.fillStyle = col;
        ctx.fill();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        ctx.strokeStyle = Main.theme.overlay(0.05);
        ctx.lineWidth = 1;
        for (const f of [0.25, 0.5, 0.75]) {
            const gy = Math.round(height * f) + 0.5;
            ctx.beginPath();
            ctx.moveTo(0, gy);
            ctx.lineTo(width, gy);
            ctx.stroke();
        }

        series(ctx, values2, color2, 0.12);
        series(ctx, values, color, 0.22);

        if (hovering && hoverIndex >= 0) {
            ctx.strokeStyle = Main.theme.overlay(0.25);
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(Math.round(hoverX) + 0.5, 0);
            ctx.lineTo(Math.round(hoverX) + 0.5, height);
            ctx.stroke();
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.CrossCursor
    }

    Text {
        visible: root.showPeak && !root.hovering && root.peak > 0
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 2
        text: "peak " + root.format(root.peak)
        color: Main.theme.colAccentDark
        font: Main.smallFont
    }

    Rectangle {
        id: bubble
        readonly property int i: root.hoverIndex
        visible: root.hovering && i >= 0
        x: Math.max(0, Math.min(root.width - width, root.hoverX + 12 + width > root.width ? root.hoverX - width - 12 : root.hoverX + 12))
        y: 4
        width: bubbleText.implicitWidth + 16
        height: bubbleText.implicitHeight + 10
        radius: Main.radius
        color: Main.theme.colBg
        border.color: Main.theme.colMuted
        border.width: 1

        Text {
            id: bubbleText
            anchors.centerIn: parent
            textFormat: Text.StyledText
            color: Main.theme.colFg
            font: Main.smallFont
            text: {
                if (bubble.i < 0)
                    return "";
                const n = Math.min(root.values.length, root.times.length);
                const off = root.values.length - n;
                const secs = Math.round((root.times[root.times.length - 1] - root.times[root.times.length - n + bubble.i]) / 1000);
                let t = "<font color='" + root.color + "'>" + root.label + root.format(root.values[off + bubble.i]) + "</font>";
                if (root.values2.length > 0) {
                    const v2 = root.values2[root.values2.length - n + bubble.i];
                    t += "<br><font color='" + root.color2 + "'>" + root.label2 + root.format(v2 ?? 0) + "</font>";
                }
                return t + "<br><font color='" + Main.theme.colAccentDark + "'>" + (secs === 0 ? "now" : "-" + secs + "s") + "</font>";
            }
        }
    }
}
