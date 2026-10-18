import QtQuick
import qs.core

// Smooth area graph of a rolling history, newest sample on the right.
// Samples are placed by their timestamp in times, so uneven sample rates still
// plot to scale. values2 is an optional second series drawn dimmer behind.
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

    readonly property real scaleMax: max > 0 ? max : Math.max(1, ...values, ...values2) * 1.2

    onValuesChanged: requestPaint()
    onValues2Changed: requestPaint()
    onTimesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function series(ctx, data, col, fillAlpha) {
        // data and times share their tail; align from the newest sample back
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

        // live dot on the newest sample
        ctx.beginPath();
        ctx.arc(x(data.length - 1) - 2, y(data[data.length - 1]), 2.5, 0, 2 * Math.PI);
        ctx.fillStyle = col;
        ctx.fill();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        // faint guide lines at 25/50/75%
        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.05);
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
    }
}
