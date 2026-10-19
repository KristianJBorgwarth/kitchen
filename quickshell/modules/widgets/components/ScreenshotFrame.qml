import QtQuick
import Quickshell.Wayland

// A monitor frozen at the moment it's created, with `marks` drawn over it (pen, arrow, box,
// marker, pixelate; see Screenshot.marks). Fills its parent; a non-empty `crop` shrinks it
// to that rectangle, so grab() then captures exactly the cropped frame with its drawings.
Item {
    id: root
    required property var screen
    property var marks: []
    property rect crop: Qt.rect(0, 0, 0, 0)
    readonly property bool cropping: crop.width > 0 && crop.height > 0
    readonly property bool ready: view.hasContent
    readonly property alias view: view

    function grab(callback): void {
        const dpr = screen.devicePixelRatio ?? 1;
        grabToImage(callback, Qt.size(Math.round(width * dpr), Math.round(height * dpr)));
    }

    // the rectangle spanned by a mark's first and last point
    function markRect(m: var): rect {
        const a = m.points[0];
        const b = m.points[m.points.length - 1];
        return Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y));
    }

    function paintMark(ctx: var, m: var): void {
        const pts = m.points;
        const a = pts[0];
        const b = pts[pts.length - 1];
        ctx.save();
        ctx.strokeStyle = m.color;
        ctx.fillStyle = m.color;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.lineWidth = m.tool === "marker" ? 18 : 4;
        ctx.globalAlpha = m.tool === "marker" ? 0.35 : 1;
        if (m.tool === "pen" || m.tool === "marker") {
            ctx.beginPath();
            ctx.moveTo(a.x, a.y);
            for (const p of pts)
                ctx.lineTo(p.x, p.y);
            ctx.stroke();
        } else if (m.tool === "box") {
            const r = markRect(m);
            ctx.strokeRect(r.x, r.y, r.width, r.height);
        } else if (m.tool === "arrow") {
            const angle = Math.atan2(b.y - a.y, b.x - a.x);
            const head = 18;
            ctx.beginPath();
            ctx.moveTo(a.x, a.y);
            ctx.lineTo(b.x - Math.cos(angle) * head * 0.6, b.y - Math.sin(angle) * head * 0.6);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(b.x, b.y);
            ctx.lineTo(b.x - head * Math.cos(angle - 0.45), b.y - head * Math.sin(angle - 0.45));
            ctx.lineTo(b.x - head * Math.cos(angle + 0.45), b.y - head * Math.sin(angle + 0.45));
            ctx.closePath();
            ctx.fill();
        }
        ctx.restore();
    }

    onMarksChanged: canvas.requestPaint()

    x: cropping ? crop.x : 0
    y: cropping ? crop.y : 0
    width: cropping ? crop.width : parent.width
    height: cropping ? crop.height : parent.height
    clip: true

    // the whole monitor, shifted so the frame stays put while the clip shrinks around it
    Item {
        x: -root.x
        y: -root.y
        width: root.screen.width
        height: root.screen.height

        ScreencopyView {
            id: view
            anchors.fill: parent
            captureSource: root.screen
            live: false
        }

        // pixelate: the frame under the rectangle sampled down to 12 px blocks
        Repeater {
            model: root.marks.filter(m => m.tool === "pixelate")

            ShaderEffectSource {
                required property var modelData
                readonly property rect r: root.markRect(modelData)
                x: r.x
                y: r.y
                width: r.width
                height: r.height
                sourceItem: view
                sourceRect: r
                textureSize: Qt.size(Math.max(1, Math.ceil(r.width / 12)), Math.max(1, Math.ceil(r.height / 12)))
                smooth: false
            }
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                for (const m of root.marks)
                    root.paintMark(ctx, m);
            }
        }
    }
}
