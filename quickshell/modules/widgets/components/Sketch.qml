import QtQuick

// Drawings over whatever is underneath: pen, arrow, box and marker, plus pixelate when
// `source` is set (it samples that item). `owner` is the Draw or Screenshot singleton:
// its `marks` tagged with `screen` are drawn, and while its `tool` is set and this is
// `interactive`, dragging draws a new one in its `ink`, or with "move" drags the one under
// the mouse. Changes go through owner.remember() first, for undo. Right click is left to
// the owner.
Item {
    id: root
    required property var owner
    required property string screen
    property Item source: null
    property bool interactive: true
    // the mark being drawn
    property var draft: null
    readonly property var marks: owner.marks.filter(m => m.screen === screen).concat(draft ? [draft] : [])
    readonly property bool moving: owner.tool === "move"
    // with "move": the index in owner.marks of the mark under the mouse, and of the one dragged
    property int hovered: -1
    property int grabbed: -1
    property point grabbedAt

    signal rightClicked

    // the rectangle spanned by a mark's first and last point
    function markRect(m: var): rect {
        const a = m.points[0];
        const b = m.points[m.points.length - 1];
        return Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y));
    }

    // the topmost mark on this screen within reach of (x, y): strokes by their line, boxes
    // and pixelate anywhere inside
    function markAt(x: real, y: real): int {
        const reach = 6;
        for (let i = owner.marks.length - 1; i >= 0; i--) {
            const m = owner.marks[i];
            if (m.screen !== screen)
                continue;
            if (m.tool === "box" || m.tool === "pixelate") {
                const r = markRect(m);
                if (x >= r.x - reach && x <= r.x + r.width + reach && y >= r.y - reach && y <= r.y + r.height + reach)
                    return i;
                continue;
            }
            const within = (m.tool === "marker" ? 9 : 2) + reach;
            const pts = m.points;
            for (let j = 0; j < pts.length; j++) {
                if (segmentDistance(x, y, pts[Math.max(0, j - 1)], pts[j]) <= within)
                    return i;
            }
        }
        return -1;
    }

    function segmentDistance(x: real, y: real, a: var, b: var): real {
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const len = dx * dx + dy * dy;
        const t = len > 0 ? Math.max(0, Math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / len)) : 0;
        return Math.hypot(x - a.x - t * dx, y - a.y - t * dy);
    }

    function shift(i: int, dx: real, dy: real): void {
        const m = owner.marks[i];
        const moved = Object.assign({}, m, { points: m.points.map(p => ({ x: p.x + dx, y: p.y + dy })) });
        owner.marks = owner.marks.slice(0, i).concat([moved], owner.marks.slice(i + 1));
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

    // pixelate: the source under the rectangle sampled down to 12 px blocks
    Repeater {
        model: root.source ? root.marks.filter(m => m.tool === "pixelate") : []

        ShaderEffectSource {
            required property var modelData
            readonly property rect r: root.markRect(modelData)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            sourceItem: root.source
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

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive && root.owner.tool !== ""
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: root.moving
        cursorShape: !root.moving ? Qt.CrossCursor : root.grabbed >= 0 ? Qt.ClosedHandCursor : root.hovered >= 0 ? Qt.OpenHandCursor : Qt.ArrowCursor

        onPressed: m => {
            if (m.button === Qt.RightButton) {
                root.rightClicked();
            } else if (root.moving) {
                root.grabbed = root.markAt(m.x, m.y);
                root.grabbedAt = Qt.point(m.x, m.y);
                if (root.grabbed >= 0)
                    root.owner.remember();
            } else {
                root.draft = { screen: root.screen, tool: root.owner.tool, color: String(root.owner.ink), points: [{ x: m.x, y: m.y }] };
            }
        }
        onPositionChanged: m => {
            if (root.moving) {
                if (root.grabbed < 0) {
                    root.hovered = root.markAt(m.x, m.y);
                } else {
                    root.shift(root.grabbed, m.x - root.grabbedAt.x, m.y - root.grabbedAt.y);
                    root.grabbedAt = Qt.point(m.x, m.y);
                }
                return;
            }
            const d = root.draft;
            if (!d)
                return;
            const p = { x: m.x, y: m.y };
            root.draft = Object.assign({}, d, { points: d.tool === "pen" || d.tool === "marker" ? d.points.concat([p]) : [d.points[0], p] });
        }
        onReleased: {
            root.grabbed = -1;
            const d = root.draft;
            if (!d)
                return;
            const r = root.markRect(d);
            if (d.points.length > 2 || r.width + r.height > 3) {
                root.owner.remember();
                root.owner.marks = root.owner.marks.concat([d]);
            }
            root.draft = null;
        }
    }
}
