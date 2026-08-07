pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Shapes

/**
 * Draws a 2D skeletal formula from an {atoms, bonds} model.
 *
 * The model uses a unit bond length with y pointing up; this scales it to fit,
 * flips it, trims every bond so it stops short of an atom label, and expands
 * double bonds and wedge/hash stereo bonds into drawable primitives.
 *
 * Rebuilding the geometry recreates every delegate below, so the result is
 * memoised against its inputs and the size is rounded to whole pixels — a
 * layout pass that hands us the same size twice must not rebuild anything.
 */
Item {
    id: root

    property var structure: null
    property real bondLength: 21          // preferred px per unit bond, shrunk to fit
    property real lineWidth: 1.6
    property real wedgeWidth: 6
    property color colMain: Appearance.colors.colOnLayer2
    property color colAccent: Appearance.colors.colPrimary
    property real labelSize: Appearance.font.pixelSize.smaller

    FontMetrics {
        id: fm
        font.family: Appearance.font.family.main
        font.pixelSize: root.labelSize
    }

    // Mutated in place, never reassigned, so it creates no binding dependency.
    readonly property var _cache: ({
            key: "",
            geo: null,
            structure: null,
            widths: {},
            ascent: 0
        })

    // One shared instance, so an unsized pass returns the same object every time.
    readonly property var _empty: ({
            lines: [],
            wedges: [],
            labels: []
        })

    // Stand-ins for the transient where a delegate still indexes into geometry
    // that has already shrunk under it.
    readonly property var _noLine: ({
            x1: 0,
            y1: 0,
            x2: 0,
            y2: 0,
            w: 0,
            col: "transparent"
        })
    readonly property var _noWedge: ({
            ax: 0,
            ay: 0,
            bx: 0,
            by: 0,
            nx: 0,
            ny: 0,
            half: 0,
            col: "transparent"
        })
    readonly property var _noLabel: ({
            text: "",
            cx: 0,
            cy: 0,
            col: "transparent"
        })

    readonly property var geometry: root.buildGeometry(root.structure, Math.round(root.width), Math.round(root.height), root.bondLength, fm.height)

    // ── Layout ───────────────────────────────────────────────────────────────

    // fm.advanceWidth() is the hot call in the fit search; labels repeat heavily
    // across the set ("O", "OH", "NH₂", …) so memoise per label string.
    function advance(text) {
        let w = root._cache.widths[text];
        if (w === undefined) {
            w = fm.advanceWidth(text);
            root._cache.widths[text] = w;
        }
        return w;
    }

    function labelExtents(atom) {
        if (!atom.label)
            return {
                l: 0,
                r: 0,
                v: 0
            };
        const w = root.advance(atom.label);
        const v = root._cache.ascent * 0.62;
        if (atom.anchor === "l")
            return {
                l: 0,
                r: w,
                v: v
            };
        if (atom.anchor === "r")
            return {
                l: w,
                r: 0,
                v: v
            };
        return {
            l: w / 2,
            r: w / 2,
            v: v
        };
    }

    // Inked bounds of the molecule at a given scale, labels included.
    function inkBounds(atoms, s, hDrop) {
        let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
        for (let i = 0; i < atoms.length; i++) {
            const a = atoms[i];
            const e = root.labelExtents(a);
            x0 = Math.min(x0, a.x * s - e.l);
            x1 = Math.max(x1, a.x * s + e.r);
            y0 = Math.min(y0, -a.y * s - e.v);
            y1 = Math.max(y1, -a.y * s + e.v + (a.h ? hDrop : 0));
        }
        return [x0, x1, y0, y1];
    }

    // Largest scale at which the molecule plus its labels still fits in w × h.
    function fitScale(atoms, w, h, maxScale, hDrop) {
        function fits(s) {
            const b = root.inkBounds(atoms, s, hDrop);
            return (b[1] - b[0]) <= w && (b[3] - b[2]) <= h;
        }
        if (fits(maxScale))
            return maxScale;
        let lo = 1, hi = maxScale;
        for (let i = 0; i < 12; i++) {
            const mid = (lo + hi) / 2;
            if (fits(mid))
                lo = mid;
            else
                hi = mid;
        }
        return lo;
    }

    // Moves `to` back along the segment until it leaves the label box of `atom`.
    function trim(fromX, fromY, toX, toY, atom, px, py) {
        if (!atom.label)
            return [toX, toY];
        const e = root.labelExtents(atom);
        const pad = 2.5;
        const left = px - e.l - pad, right = px + e.r + pad;
        const top = py - e.v - pad, bottom = py + e.v + pad;
        let dx = fromX - toX, dy = fromY - toY;
        const len = Math.hypot(dx, dy);
        if (len < 0.001)
            return [toX, toY];
        dx /= len;
        dy /= len;
        const tx = dx > 0 ? (right - toX) / dx : (dx < 0 ? (left - toX) / dx : Infinity);
        const ty = dy > 0 ? (bottom - toY) / dy : (dy < 0 ? (top - toY) / dy : Infinity);
        const t = Math.min(tx, ty, len);
        return [toX + dx * t, toY + dy * t];
    }

    function buildGeometry(structure, w, h, maxBond, metricsRevision) {
        if (!structure || !structure.atoms || structure.atoms.length === 0 || w <= 0 || h <= 0)
            return root._empty;

        // Memoise: identical inputs must return the very same object, otherwise
        // the Repeaters below tear down and rebuild every delegate. The molecule
        // itself is compared by identity — atom/bond counts alone would let
        // different amino acids collide (Leu and Ile are both 9 atoms, 8 bonds).
        const key = [w, h, maxBond, metricsRevision, root.labelSize, root.lineWidth, root.wedgeWidth, String(root.colMain), String(root.colAccent)].join("|");
        if (root._cache.key === key && root._cache.geo && root._cache.structure === structure)
            return root._cache.geo;

        if (root._cache.ascent !== fm.ascent) {
            root._cache.ascent = fm.ascent;
            root._cache.widths = {};
        }

        const atoms = structure.atoms;
        const hDrop = fm.height * 0.8;
        const s = root.fitScale(atoms, w, h, maxBond, hDrop);

        // Scene-space atom positions, then centre the inked bounds in the item.
        const b = root.inkBounds(atoms, s, hDrop);
        const ox = (w - (b[1] - b[0])) / 2 - b[0];
        const oy = (h - (b[3] - b[2])) / 2 - b[2];

        const P = [];
        for (let i = 0; i < atoms.length; i++)
            P.push([atoms[i].x * s + ox, -atoms[i].y * s + oy]);

        const lines = [];
        const wedges = [];
        const wedgeW = root.wedgeWidth * Math.min(1, s / maxBond + 0.35);

        for (let i = 0; i < structure.bonds.length; i++) {
            const bond = structure.bonds[i];
            if (bond.order === 0)
                continue;
            const A = atoms[bond.a], B = atoms[bond.b];
            let ax = P[bond.a][0], ay = P[bond.a][1];
            let bx = P[bond.b][0], by = P[bond.b][1];

            const ta = root.trim(bx, by, ax, ay, A, P[bond.a][0], P[bond.a][1]);
            ax = ta[0];
            ay = ta[1];
            const tb = root.trim(ax, ay, bx, by, B, P[bond.b][0], P[bond.b][1]);
            bx = tb[0];
            by = tb[1];

            const col = bond.accent ? root.colAccent : root.colMain;
            const dx = bx - ax, dy = by - ay;
            const len = Math.hypot(dx, dy);
            if (len < 0.5)
                continue;
            const ux = dx / len, uy = dy / len;
            const nx = -uy, ny = ux;   // unit normal

            if (bond.stereo === "wedge") {
                wedges.push({
                    ax: ax,
                    ay: ay,
                    bx: bx,
                    by: by,
                    nx: nx,
                    ny: ny,
                    half: wedgeW / 2,
                    col: col
                });
                continue;
            }

            if (bond.stereo === "dash") {
                const n = 5;
                for (let k = 1; k <= n; k++) {
                    const t = k / n;
                    const cx = ax + ux * len * t, cy = ay + uy * len * t;
                    const half = wedgeW / 2 * t;
                    lines.push({
                        x1: cx - nx * half,
                        y1: cy - ny * half,
                        x2: cx + nx * half,
                        y2: cy + ny * half,
                        w: root.lineWidth,
                        col: col
                    });
                }
                continue;
            }

            if (bond.order === 2) {
                const gap = Math.max(2.6, s * 0.16);
                if (bond.toward) {
                    // Ring-style: full outer line plus a shortened inner line.
                    const tx = bond.toward[0] * s + ox, ty = -bond.toward[1] * s + oy;
                    const mx = (ax + bx) / 2, my = (ay + by) / 2;
                    const sign = ((tx - mx) * nx + (ty - my) * ny) >= 0 ? 1 : -1;
                    lines.push({
                        x1: ax,
                        y1: ay,
                        x2: bx,
                        y2: by,
                        w: root.lineWidth,
                        col: col
                    });
                    const inset = len * 0.16;
                    lines.push({
                        x1: ax + ux * inset + nx * gap * sign,
                        y1: ay + uy * inset + ny * gap * sign,
                        x2: bx - ux * inset + nx * gap * sign,
                        y2: by - uy * inset + ny * gap * sign,
                        w: root.lineWidth,
                        col: col
                    });
                } else {
                    for (const sign of [-1, 1]) {
                        lines.push({
                            x1: ax + nx * gap / 2 * sign,
                            y1: ay + ny * gap / 2 * sign,
                            x2: bx + nx * gap / 2 * sign,
                            y2: by + ny * gap / 2 * sign,
                            w: root.lineWidth,
                            col: col
                        });
                    }
                }
                continue;
            }

            lines.push({
                x1: ax,
                y1: ay,
                x2: bx,
                y2: by,
                w: root.lineWidth,
                col: col
            });
        }

        const labels = [];
        for (let i = 0; i < atoms.length; i++) {
            const a = atoms[i];
            if (!a.label)
                continue;
            const wpx = root.advance(a.label);
            const cx = a.anchor === "l" ? P[i][0] + wpx / 2 : (a.anchor === "r" ? P[i][0] - wpx / 2 : P[i][0]);
            const col = a.accent ? root.colAccent : root.colMain;
            labels.push({
                text: a.label,
                cx: cx,
                cy: P[i][1],
                col: col
            });

            // Implicit hydrogen: a label in its own right, stacked on the atom's.
            if (a.h !== "below" && a.h !== "above")
                continue;
            labels.push({
                text: "H",
                cx: cx,
                cy: P[i][1] + (a.h === "below" ? fm.height * 0.78 : -fm.height * 0.78),
                col: col
            });
        }

        const result = {
            lines: lines,
            wedges: wedges,
            labels: labels
        };
        root._cache.key = key;
        root._cache.geo = result;
        root._cache.structure = structure;
        return result;
    }

    // ── Drawing ──────────────────────────────────────────────────────────────

    // The models are counts, not the arrays themselves: handing a Repeater a new
    // array destroys and recreates every delegate, and the layout settles through
    // several sizes before it lands, so each card would rebuild several times over.

    Repeater {
        model: root.geometry.lines.length

        delegate: Rectangle {
            required property int index
            readonly property var d: root.geometry.lines[index] ?? root._noLine
            readonly property real len: Math.hypot(d.x2 - d.x1, d.y2 - d.y1)
            x: (d.x1 + d.x2) / 2 - len / 2
            y: (d.y1 + d.y2) / 2 - d.w / 2
            width: len
            height: d.w
            radius: d.w / 2
            color: d.col
            antialiasing: true
            transformOrigin: Item.Center
            rotation: Math.atan2(d.y2 - d.y1, d.x2 - d.x1) * 180 / Math.PI
        }
    }

    Repeater {
        model: root.geometry.wedges.length

        // Plain triangles — the default geometry renderer is much cheaper here
        // than CurveRenderer, which would compile shaders per Shape.
        delegate: Shape {
            id: wedge
            required property int index
            readonly property var d: root.geometry.wedges[index] ?? root._noWedge
            anchors.fill: parent

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: wedge.d.col
                startX: wedge.d.ax
                startY: wedge.d.ay

                PathLine {
                    x: wedge.d.bx + wedge.d.nx * wedge.d.half
                    y: wedge.d.by + wedge.d.ny * wedge.d.half
                }
                PathLine {
                    x: wedge.d.bx - wedge.d.nx * wedge.d.half
                    y: wedge.d.by - wedge.d.ny * wedge.d.half
                }
                PathLine {
                    x: wedge.d.ax
                    y: wedge.d.ay
                }
            }
        }
    }

    Repeater {
        model: root.geometry.labels.length

        delegate: StyledText {
            id: labelText
            required property int index
            readonly property var d: root.geometry.labels[index] ?? root._noLabel
            x: d.cx - width / 2
            y: d.cy - height / 2
            text: d.text
            color: d.col
            font.pixelSize: root.labelSize
        }
    }
}
