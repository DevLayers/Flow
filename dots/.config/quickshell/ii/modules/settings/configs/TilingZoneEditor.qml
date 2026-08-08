import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "../../common/functions/tiling.js" as Tiling

/**
 * Drag-to-draw editor for one monitor's tiling zones.
 *
 * Everything here happens in fraction space (0..1 of the usable area), which is
 * how zones are stored, so a layout drawn on one monitor keeps its proportions
 * on another and survives a resolution or scale change.
 *
 * Dragging empty space draws a new zone, dragging a zone body moves it and
 * dragging one of its handles resizes it. Edges snap to the neighbours they are
 * probably meant to meet, and to a grid otherwise. Zones may overlap: which one
 * a window lands in is decided by the cursor, so overlapping is a valid layout
 * rather than something to prevent.
 */
Item {
    id: root

    property var zones: []
    property real aspect: 16 / 9
    property real snapStep: 1 / 24
    // How near an existing edge counts as meaning that edge.
    property real snapTolerance: 0.02
    // Matches Tiling.sanitizeZones, so nothing drawn here can be dropped later
    // for being too small.
    property real minSize: 0.05
    property int selectedIndex: -1
    // Read-only turns the editor into a preview, which is how the shipped
    // presets get shown without letting anyone edit them into something that
    // is no longer the preset.
    property bool readOnly: false
    // A monitor is much wider than a settings page is tall, so the canvas is
    // capped and centred rather than filling the width.
    property real maxCanvasHeight: 260

    readonly property int handleSize: 12
    readonly property bool editing: gesture.mode !== "none"

    // Overlapping zones are a valid layout - the cursor decides which of them a
    // window lands in - but two windows tiled into the same space cover each
    // other, and nothing on the screen itself says the zones were drawn that
    // way. The editor is the only place it can be seen, so it is shown rather
    // than prevented.
    readonly property var overlaps: {
        const list = Array.from(root.zones ?? []);
        const out = [];
        for (let i = 0; i < list.length; i++) {
            for (let j = i + 1; j < list.length; j++) {
                const x = Math.max(list[i].x, list[j].x);
                const y = Math.max(list[i].y, list[j].y);
                const right = Math.min(list[i].x + list[i].w, list[j].x + list[j].w);
                const bottom = Math.min(list[i].y + list[i].h, list[j].y + list[j].h);
                // Zones drawn edge to edge meet without overlapping, and a
                // rounding error is not worth painting a warning over.
                if (right - x < 0.002 || bottom - y < 0.002) continue;
                out.push({
                    "x": x,
                    "y": y,
                    "w": right - x,
                    "h": bottom - y
                });
            }
        }
        return out;
    }
    readonly property int overlapCount: root.overlaps.length

    signal zonesEdited(var updated)

    implicitHeight: canvas.height

    onZonesChanged: {
        if (root.selectedIndex >= (root.zones?.length ?? 0)) root.selectedIndex = -1;
    }

    // ------------------------------------------------------------ geometry

    function fractionAt(px, py) {
        return {
            "x": Tiling.clamp(px / Math.max(1, canvas.width), 0, 1),
            "y": Tiling.clamp(py / Math.max(1, canvas.height), 0, 1)
        };
    }

    // Tolerates a missing zone: the handle delegates keep their bindings for an
    // instant after the selected zone is deleted or the list is replaced.
    function pixelRect(zone) {
        if (!zone) return Qt.rect(0, 0, 0, 0);
        return Qt.rect(zone.x * canvas.width, zone.y * canvas.height, zone.w * canvas.width, zone.h * canvas.height);
    }

    // An edge the user is likely aiming for wins over the grid, so zones drawn
    // one after another line up exactly instead of a hair apart.
    function snapValue(value, horizontal, skip) {
        const list = Array.from(root.zones);
        let best = NaN;
        let bestDistance = root.snapTolerance;
        const candidates = [0, 1];
        for (let i = 0; i < list.length; i++) {
            if (i === skip) continue;
            candidates.push(horizontal ? list[i].x : list[i].y);
            candidates.push(horizontal ? list[i].x + list[i].w : list[i].y + list[i].h);
        }
        for (const candidate of candidates) {
            const distance = Math.abs(value - candidate);
            if (distance > bestDistance) continue;
            best = candidate;
            bestDistance = distance;
        }
        if (!isNaN(best)) return best;
        return Tiling.clamp(Math.round(value / root.snapStep) * root.snapStep, 0, 1);
    }

    // Last drawn is topmost, which is the one the user sees and means to grab.
    function zoneAt(fx, fy) {
        const list = Array.from(root.zones);
        for (let i = list.length - 1; i >= 0; i--) {
            const zone = list[i];
            if (fx >= zone.x && fx <= zone.x + zone.w && fy >= zone.y && fy <= zone.y + zone.h) return i;
        }
        return -1;
    }

    // Which of the eight handles the press landed on, as a pair of -1/0/1, or
    // null when it missed them all.
    function handleAt(zone, px, py) {
        const rect = root.pixelRect(zone);
        for (let hy = -1; hy <= 1; hy++) {
            for (let hx = -1; hx <= 1; hx++) {
                if (hx === 0 && hy === 0) continue;
                const cx = rect.x + rect.width * (hx + 1) / 2;
                const cy = rect.y + rect.height * (hy + 1) / 2;
                if (Math.abs(px - cx) <= root.handleSize && Math.abs(py - cy) <= root.handleSize)
                    return {
                        "x": hx,
                        "y": hy
                    };
            }
        }
        return null;
    }

    function draftRect(from, to) {
        const left = root.snapValue(Math.min(from.x, to.x), true, -1);
        const right = root.snapValue(Math.max(from.x, to.x), true, -1);
        const top = root.snapValue(Math.min(from.y, to.y), false, -1);
        const bottom = root.snapValue(Math.max(from.y, to.y), false, -1);
        return {
            "x": left,
            "y": top,
            "w": Math.max(0, right - left),
            "h": Math.max(0, bottom - top)
        };
    }

    function movedZone(origin, from, to) {
        const x = root.snapValue(Tiling.clamp(origin.x + to.x - from.x, 0, 1 - origin.w), true, root.selectedIndex);
        const y = root.snapValue(Tiling.clamp(origin.y + to.y - from.y, 0, 1 - origin.h), false, root.selectedIndex);
        return {
            "x": Tiling.clamp(x, 0, 1 - origin.w),
            "y": Tiling.clamp(y, 0, 1 - origin.h),
            "w": origin.w,
            "h": origin.h,
            "label": origin.label
        };
    }

    // The opposite edge stays put, so a handle drag reads as pulling one side
    // rather than sliding the whole zone.
    function resizedZone(origin, from, to) {
        const index = root.selectedIndex;
        let left = origin.x;
        let right = origin.x + origin.w;
        let top = origin.y;
        let bottom = origin.y + origin.h;

        if (gesture.handleX < 0)
            left = Math.min(root.snapValue(left + to.x - from.x, true, index), right - root.minSize);
        if (gesture.handleX > 0)
            right = Math.max(root.snapValue(right + to.x - from.x, true, index), left + root.minSize);
        if (gesture.handleY < 0)
            top = Math.min(root.snapValue(top + to.y - from.y, false, index), bottom - root.minSize);
        if (gesture.handleY > 0)
            bottom = Math.max(root.snapValue(bottom + to.y - from.y, false, index), top + root.minSize);

        return {
            "x": left,
            "y": top,
            "w": right - left,
            "h": bottom - top,
            "label": origin.label
        };
    }

    // ------------------------------------------------------------- gesture

    QtObject {
        id: gesture

        property string mode: "none"  // none | draw | move | resize
        property var start: null
        property var origin: null
        property var draft: null
        property int handleX: 0
        property int handleY: 0
    }

    // --------------------------------------------------------------- paint

    Rectangle {
        id: canvas

        readonly property real ratio: Math.max(0.2, root.aspect)

        anchors.horizontalCenter: parent.horizontalCenter
        height: Math.round(Math.min(root.width / ratio, root.maxCanvasHeight))
        width: Math.round(height * ratio)
        radius: Appearance.rounding.small
        color: Appearance.colors.colSurfaceContainerHigh
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
        clip: true

        StyledText {
            anchors.centerIn: parent
            visible: (root.zones?.length ?? 0) === 0 && gesture.mode === "none" && !root.readOnly
            text: Translation.tr("Drag to draw a zone")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }

        Repeater {
            model: root.zones

            delegate: Rectangle {
                id: zoneRect

                required property var modelData
                required property int index

                readonly property bool selected: root.selectedIndex === index
                // While a move or resize is in flight the draft below stands in
                // for this zone, so drawing both would double it up.
                visible: !(selected && gesture.draft !== null && gesture.mode !== "draw")

                x: Math.round(modelData.x * canvas.width)
                y: Math.round(modelData.y * canvas.height)
                width: Math.round(modelData.w * canvas.width)
                height: Math.round(modelData.h * canvas.height)
                radius: Appearance.rounding.verysmall
                color: ColorUtils.applyAlpha(Appearance.colors.colPrimaryContainer, selected ? 0.85 : 0.4)
                border.width: selected ? 2 : 1
                border.color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, selected ? 1 : 0.45)

                StyledText {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: Tiling.labelFor(zoneRect.modelData)
                    color: Appearance.colors.colOnPrimaryContainer
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
        }

        Repeater {
            // Nothing while a gesture is in flight: these come from the stored
            // zones, and the draft below is not one of them yet, so they would
            // be hatching a layout that is no longer the one on screen.
            model: gesture.mode === "none" ? root.overlaps : 0

            delegate: Item {
                id: overlapPatch

                required property var modelData

                // Long enough that a bar leaning across the patch at 45 degrees
                // still crosses it from corner to corner.
                readonly property real span: overlapPatch.width + overlapPatch.height

                x: Math.round(modelData.x * canvas.width)
                y: Math.round(modelData.y * canvas.height)
                width: Math.round(modelData.w * canvas.width)
                height: Math.round(modelData.h * canvas.height)
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: ColorUtils.applyAlpha(Appearance.colors.colError, 0.16)
                }

                Repeater {
                    // Diagonal hatching: upright bars rotated about their own
                    // centre, stepped across the patch. The first centres half a
                    // patch-height off the left edge, which is how far a leaning
                    // bar reaches back.
                    model: Math.ceil(overlapPatch.span / 10) + 1

                    delegate: Rectangle {
                        required property int index

                        width: 2
                        height: overlapPatch.span * 1.5
                        x: index * 10 - overlapPatch.height / 2 - width / 2
                        y: (overlapPatch.height - height) / 2
                        color: ColorUtils.applyAlpha(Appearance.colors.colError, 0.4)
                        transformOrigin: Item.Center
                        rotation: 45
                    }
                }
            }
        }

        Rectangle {
            visible: gesture.draft !== null
            x: Math.round((gesture.draft?.x ?? 0) * canvas.width)
            y: Math.round((gesture.draft?.y ?? 0) * canvas.height)
            width: Math.round((gesture.draft?.w ?? 0) * canvas.width)
            height: Math.round((gesture.draft?.h ?? 0) * canvas.height)
            radius: Appearance.rounding.verysmall
            color: ColorUtils.applyAlpha(Appearance.colors.colPrimaryContainer, 0.85)
            border.width: 2
            border.color: Appearance.colors.colPrimary
        }

        Repeater {
            // The eight handles of the selected zone, centre excluded.
            model: root.selectedIndex >= 0 && gesture.mode === "none" && !root.readOnly ? 9 : 0

            delegate: Rectangle {
                required property int index

                readonly property int handleX: (index % 3) - 1
                readonly property int handleY: Math.floor(index / 3) - 1
                readonly property var zone: root.zones[root.selectedIndex]
                readonly property rect box: root.pixelRect(zone)

                visible: handleX !== 0 || handleY !== 0
                width: root.handleSize
                height: root.handleSize
                radius: width / 2
                x: Math.round(box.x + box.width * (handleX + 1) / 2 - width / 2)
                y: Math.round(box.y + box.height * (handleY + 1) / 2 - height / 2)
                color: Appearance.colors.colPrimary
                border.width: 2
                border.color: Appearance.colors.colOnPrimary
            }
        }
    }

    // ---------------------------------------------------------- interaction

    MouseArea {
        anchors.fill: canvas
        enabled: !root.readOnly
        hoverEnabled: true
        // The settings page scrolls vertically, and it would otherwise take
        // every drag that has any height to it: a zone could be made wider but
        // never taller. Scrolling the page over the canvas is the wheel's job.
        preventStealing: true
        cursorShape: gesture.mode === "move" ? Qt.ClosedHandCursor : Qt.CrossCursor

        onPressed: event => {
            const point = root.fractionAt(event.x, event.y);
            const selected = root.zones[root.selectedIndex] ?? null;
            const handle = selected ? root.handleAt(selected, event.x, event.y) : null;
            gesture.start = point;

            if (handle) {
                gesture.mode = "resize";
                gesture.handleX = handle.x;
                gesture.handleY = handle.y;
                gesture.origin = selected;
                return;
            }

            const index = root.zoneAt(point.x, point.y);
            root.selectedIndex = index;
            if (index < 0) {
                gesture.mode = "draw";
                gesture.origin = null;
                return;
            }
            gesture.mode = "move";
            gesture.origin = root.zones[index];
        }

        onPositionChanged: event => {
            if (gesture.mode === "none") return;
            const point = root.fractionAt(event.x, event.y);
            if (gesture.mode === "draw") gesture.draft = root.draftRect(gesture.start, point);
            else if (gesture.mode === "move") gesture.draft = root.movedZone(gesture.origin, gesture.start, point);
            else gesture.draft = root.resizedZone(gesture.origin, gesture.start, point);
        }

        onReleased: {
            const mode = gesture.mode;
            const draft = gesture.draft;
            gesture.mode = "none";
            gesture.draft = null;
            gesture.origin = null;
            if (!draft) return;

            const list = Array.from(root.zones);
            if (mode === "draw") {
                // A click rather than a drag: it selected nothing, which is all
                // it was ever going to do.
                if (draft.w < root.minSize || draft.h < root.minSize) return;
                list.push(draft);
                root.selectedIndex = list.length - 1;
            } else if (root.selectedIndex >= 0 && root.selectedIndex < list.length) {
                list[root.selectedIndex] = draft;
            } else {
                return;
            }
            root.zonesEdited(Tiling.sanitizeZones(list, root.minSize));
        }

        onCanceled: {
            gesture.mode = "none";
            gesture.draft = null;
            gesture.origin = null;
        }
    }
}
