.pragma library

// Data for the 22 proteinogenic amino acids, plus 2D skeletal structures.
//
// Structures use a unit bond length of 1 with the α-carbon at the origin and
// y pointing UP (the renderer flips it). Bond directions are the six standard
// skeletal headings, so every vertex sits on 120° angles.
//
// pKa / pI values follow Nelson DL, Cox MM. Lehninger Principles of
// Biochemistry. 7th ed. New York: W.H. Freeman; 2017. Table 3-1.
// Hydropathy is the Kyte-Doolittle index.

const UL = [-0.8660, 0.5];    // 150°
const DL = [-0.8660, -0.5];   // 210°
const UR = [0.8660, 0.5];     // 30°
const DR = [0.8660, -0.5];    // 330°
const UP = [0, 1];            // 90°
const DOWN = [0, -1];         // 270°

// ── Structure builder ────────────────────────────────────────────────────────

function make(builder) {
    const atoms = [];
    const bonds = [];
    let accent = false;

    const api = {
        // Everything declared after accent(true) is part of the side chain and
        // gets the class colour.
        accent: function (v) {
            accent = v;
            return api;
        },
        at: function (x, y, o) {
            const a = {
                x: x,
                y: y,
                label: "",
                anchor: "c",   // c | l | r  — which edge of the text sits on the atom
                h: "",         // "below" | "above" — draws an implicit H next to the label
                accent: accent
            };
            for (const k in (o || {}))
                a[k] = o[k];
            atoms.push(a);
            return atoms.length - 1;
        },
        step: function (i, dir, o) {
            return api.at(atoms[i].x + dir[0], atoms[i].y + dir[1], o);
        },
        link: function (a, b, o) {
            const t = {
                a: a,
                b: b,
                order: 1,
                stereo: "",    // "wedge" | "dash"
                toward: null,  // second line of a double bond leans toward this point
                accent: accent
            };
            for (const k in (o || {}))
                t[k] = o[k];
            bonds.push(t);
        },
        // Closes a ring through the given atom indices with the given bond orders.
        ring: function (idx, orders) {
            const cx = idx.reduce((s, i) => s + atoms[i].x, 0) / idx.length;
            const cy = idx.reduce((s, i) => s + atoms[i].y, 0) / idx.length;
            for (let i = 0; i < idx.length; i++) {
                api.link(idx[i], idx[(i + 1) % idx.length], {
                    order: orders[i],
                    toward: orders[i] === 2 ? [cx, cy] : null
                });
            }
        }
    };

    builder(api);
    return {
        atoms: atoms,
        bonds: bonds
    };
}

// Standard α-amino acid backbone: NH₂ below Cα, COOH up to the right.
// The Cα→Cβ bond is drawn as a wedge by each side chain, which fixes the
// L (2S) configuration.
function backbone(api, opt) {
    const o = opt || {};
    const ca = api.at(0, 0);
    const n = o.ringN ? api.at(0, -1, {
        label: "N",
        h: "below"
    }) : api.at(0, -1, {
        label: "NH₂"
    });
    const c = api.at(0.8660, 0.5);
    const od = api.at(0.8660, 1.5, {
        label: "O"
    });
    const oh = api.at(1.7320, 0.0, {
        label: "OH",
        anchor: "l"
    });
    api.link(ca, n);
    api.link(ca, c);
    api.link(c, od, {
        order: 2
    });
    api.link(c, oh);
    return {
        ca: ca,
        n: n,
        c: c,
        o: od,
        oh: oh
    };
}

// Regular polygon vertices, used for the ring systems.
// Returns n points of a polygon with unit sides, whose first vertex is `start`
// and whose centre lies one circumradius away along `heading` (in degrees).
function polygon(n, start, headingDeg) {
    const R = 0.5 / Math.sin(Math.PI / n);
    const h = headingDeg * Math.PI / 180;
    const cx = start[0] + R * Math.cos(h);
    const cy = start[1] + R * Math.sin(h);
    const a0 = Math.atan2(start[1] - cy, start[0] - cx);
    const pts = [];
    for (let i = 0; i < n; i++) {
        const a = a0 + i * 2 * Math.PI / n;
        pts.push([cx + R * Math.cos(a), cy + R * Math.sin(a)]);
    }
    return pts;
}

// ── Side chains ──────────────────────────────────────────────────────────────

function sGly() {
    return make(api => {
        backbone(api);
    });
}

function sAla() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
    });
}

function sVal() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const g1 = api.step(cb, UL);
        const g2 = api.step(cb, DL);
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, g1);
        api.link(cb, g2);
    });
}

function sLeu() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const cg = api.step(cb, DL);
        const d1 = api.step(cg, UL);
        const d2 = api.step(cg, DL);
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, cg);
        api.link(cg, d1);
        api.link(cg, d2);
    });
}

function sIle() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const g2 = api.step(cb, UP);     // Cγ2 methyl, hashed → (3S)
        const g1 = api.step(cb, DL);     // Cγ1
        const d1 = api.step(g1, UL);     // Cδ1
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, g2, {
            stereo: "dash"
        });
        api.link(cb, g1);
        api.link(g1, d1);
    });
}

function sPro() {
    return make(api => {
        const bb = backbone(api, {
            ringN: true
        });
        api.accent(true);
        // Pyrrolidine ring closing Cα back onto the backbone nitrogen.
        const p = polygon(5, [0, 0], 216);
        const cb = api.at(p[1][0], p[1][1]);
        const cg = api.at(p[2][0], p[2][1]);
        const cd = api.at(p[3][0], p[3][1]);
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, cg);
        api.link(cg, cd);
        api.link(cd, bb.n);
    });
}

function sMet() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const cg = api.step(cb, DL);
        const sd = api.step(cg, UL, {
            label: "S"
        });
        const ce = api.step(sd, DL);
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, cg);
        api.link(cg, sd);
        api.link(sd, ce);
    });
}

function sPhe() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        const c1 = api.step(cb, DL);
        api.link(cb, c1);
        const p = polygon(6, [-1.7320, 0.0], 210);
        const r = [c1];
        for (let i = 1; i < 6; i++)
            r.push(api.at(p[i][0], p[i][1]));
        api.ring(r, [2, 1, 2, 1, 2, 1]);
    });
}

function sTyr() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        const c1 = api.step(cb, DL);
        api.link(cb, c1);
        const p = polygon(6, [-1.7320, 0.0], 210);
        const r = [c1];
        for (let i = 1; i < 6; i++)
            r.push(api.at(p[i][0], p[i][1]));
        api.ring(r, [2, 1, 2, 1, 2, 1]);
        // para hydroxyl
        const oh = api.step(r[3], DL, {
            label: "HO",
            anchor: "r"
        });
        api.link(r[3], oh);
    });
}

function sTrp() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        // Indole, laid out in a local frame then translated so C3 meets Cβ.
        const dx = -1.7320 - 0.9511;
        const dy = 0.0 - 0.8090;
        const A = (x, y, o) => api.at(x + dx, y + dy, o);
        const c3 = A(0.9511, 0.8090);
        const c2 = A(1.5389, 0.0);
        const n1 = A(0.9511, -0.8090, {
            label: "N",
            h: "below"
        });
        const c7a = A(0.0, -0.5);
        const c3a = A(0.0, 0.5);
        const c4 = A(-0.8660, 1.0);
        const c5 = A(-1.7320, 0.5);
        const c6 = A(-1.7320, -0.5);
        const c7 = A(-0.8660, -1.0);
        api.link(cb, c3);
        api.ring([c3, c2, n1, c7a, c3a], [2, 1, 1, 0, 1]);
        api.ring([c3a, c4, c5, c6, c7, c7a], [1, 2, 1, 2, 1, 2]);
    });
}

function sSer() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const og = api.step(cb, DL, {
            label: "HO",
            anchor: "r"
        });
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, og);
    });
}

function sThr() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const og = api.step(cb, UP, {
            label: "OH"
        });
        const g2 = api.step(cb, DL);   // methyl on a wedge → (3R)
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, og);
        api.link(cb, g2, {
            stereo: "wedge"
        });
    });
}

function sCys() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const sg = api.step(cb, DL, {
            label: "HS",
            anchor: "r"
        });
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, sg);
    });
}

function sSec() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const seg = api.step(cb, DL, {
            label: "HSe",
            anchor: "r"
        });
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, seg);
    });
}

function sAsn() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const cg = api.step(cb, DL);
        const od = api.step(cg, DOWN, {
            label: "O"
        });
        const nd = api.step(cg, UL, {
            label: "H₂N",
            anchor: "r"
        });
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, cg);
        api.link(cg, od, {
            order: 2
        });
        api.link(cg, nd);
    });
}

function sGln() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const cg = api.step(cb, DL);
        const cd = api.step(cg, UL);
        const oe = api.step(cd, UP, {
            label: "O"
        });
        const ne = api.step(cd, DL, {
            label: "H₂N",
            anchor: "r"
        });
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, cg);
        api.link(cg, cd);
        api.link(cd, oe, {
            order: 2
        });
        api.link(cd, ne);
    });
}

function sAsp() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const cg = api.step(cb, DL);
        const od = api.step(cg, DOWN, {
            label: "O"
        });
        const oh = api.step(cg, UL, {
            label: "HO",
            anchor: "r"
        });
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, cg);
        api.link(cg, od, {
            order: 2
        });
        api.link(cg, oh);
    });
}

function sGlu() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const cg = api.step(cb, DL);
        const cd = api.step(cg, UL);
        const oe = api.step(cd, UP, {
            label: "O"
        });
        const oh = api.step(cd, DL, {
            label: "HO",
            anchor: "r"
        });
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, cg);
        api.link(cg, cd);
        api.link(cd, oe, {
            order: 2
        });
        api.link(cd, oh);
    });
}

function sLys() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const cg = api.step(cb, DL);
        const cd = api.step(cg, UL);
        const ce = api.step(cd, DL);
        const nz = api.step(ce, UL, {
            label: "H₂N",
            anchor: "r"
        });
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, cg);
        api.link(cg, cd);
        api.link(cd, ce);
        api.link(ce, nz);
    });
}

function sArg() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const cg = api.step(cb, DL);
        const cd = api.step(cg, UL);
        const ne = api.step(cd, DL, {
            label: "N",
            h: "below"
        });
        const cz = api.step(ne, DL);
        const nh1 = api.step(cz, UL, {
            label: "HN",
            anchor: "r"
        });
        const nh2 = api.step(cz, DOWN, {
            label: "NH₂"
        });
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, cg);
        api.link(cg, cd);
        api.link(cd, ne);
        api.link(ne, cz);
        api.link(cz, nh1, {
            order: 2
        });
        api.link(cz, nh2);
    });
}

function sHis() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        const cg = api.step(cb, DL);
        api.link(cb, cg);
        // Imidazole, Nε2-H tautomer.
        const q = polygon(5, [-1.7320, 0.0], 210);
        const nd1 = api.at(q[1][0], q[1][1], {
            label: "N"
        });
        const ce1 = api.at(q[2][0], q[2][1]);
        const ne2 = api.at(q[3][0], q[3][1], {
            label: "N",
            h: "below"
        });
        const cd2 = api.at(q[4][0], q[4][1]);
        api.ring([cg, nd1, ce1, ne2, cd2], [1, 2, 1, 1, 2]);
    });
}

function sPyl() {
    return make(api => {
        const bb = backbone(api);
        api.accent(true);
        const cb = api.step(bb.ca, UL);
        const cg = api.step(cb, DL);
        const cd = api.step(cg, UL);
        const ce = api.step(cd, DL);
        const nz = api.step(ce, UL, {
            label: "N",
            h: "below"
        });
        api.link(bb.ca, cb, {
            stereo: "wedge"
        });
        api.link(cb, cg);
        api.link(cg, cd);
        api.link(cd, ce);
        api.link(ce, nz);
        // Amide link to (4R,5R)-4-methylpyrroline-5-carboxylate
        const cam = api.step(nz, DL);
        const oam = api.step(cam, DOWN, {
            label: "O"
        });
        api.link(nz, cam);
        api.link(cam, oam, {
            order: 2
        });
        const c5 = api.step(cam, UL);
        api.link(cam, c5);
        const q = polygon(5, [-6.0622, 0.5], 150);
        const c4 = api.at(q[1][0], q[1][1]);
        const c3 = api.at(q[2][0], q[2][1]);
        const c2 = api.at(q[3][0], q[3][1]);
        const n1 = api.at(q[4][0], q[4][1], {
            label: "N"
        });
        api.ring([c5, c4, c3, c2, n1], [1, 1, 1, 2, 1]);
        const me = api.step(c4, UP);
        api.link(c4, me);
    });
}

// ── Classification schemes ───────────────────────────────────────────────────
//
// Each amino acid carries its class under all three schemes so the grid can be
// recoloured by swapping `defaultScheme` (or whatever the caller passes).

// Classes are coloured relative to the active matugen palette, never absolutely:
// ColorUtils.categoryAccent() adds `hueOffset` to the theme's own hue and takes
// saturation from it too, so the whole set turns with the wallpaper.
//
// Offsets stay inside ±50° of the theme hue — an analogous family, so every
// class still reads as part of the palette instead of a rainbow that happens to
// be phase-shifted. That arc is too narrow to separate seven classes on its own,
// so `shade` climbs a tonal ladder as a second axis and cycles every three
// entries; neighbours in hue therefore always differ in weight as well.
const schemes = {
    five: {
        label: "5 classes",
        classes: [
            { key: "nonpolar", name: "Nonpolar, aliphatic", hueOffset: -50, shade: 0 },
            { key: "aromatic", name: "Aromatic", hueOffset: -25, shade: 1 },
            { key: "polar", name: "Polar, uncharged", hueOffset: 0, shade: 2 },
            { key: "acidic", name: "Acidic (−)", hueOffset: 25, shade: 0 },
            { key: "basic", name: "Basic (+)", hueOffset: 50, shade: 1 }
        ]
    },
    seven: {
        label: "7 classes",
        classes: [
            { key: "aliphatic", name: "Aliphatic", hueOffset: -50, shade: 0 },
            { key: "aromatic", name: "Aromatic", hueOffset: -33, shade: 1 },
            { key: "amidic", name: "Amidic", hueOffset: -17, shade: 2 },
            { key: "hydroxylic", name: "Hydroxylic", hueOffset: 0, shade: 0 },
            { key: "chargedPos", name: "Positively charged", hueOffset: 17, shade: 1 },
            { key: "chargedNeg", name: "Negatively charged", hueOffset: 33, shade: 2 },
            { key: "sulfur", name: "Sulfur / selenium", hueOffset: 50, shade: 0 }
        ]
    },
    four: {
        label: "4 classes",
        classes: [
            { key: "charged", name: "Charged", hueOffset: -50, shade: 0 },
            { key: "polar", name: "Polar, uncharged", hueOffset: -17, shade: 1 },
            { key: "hydrophobic", name: "Hydrophobic", hueOffset: 17, shade: 2 },
            { key: "special", name: "Special cases", hueOffset: 50, shade: 0 }
        ]
    }
};

const defaultScheme = "five";

function scheme(name) {
    return schemes[name] || schemes[defaultScheme];
}

function classOf(aa, schemeName) {
    return aa.classes[schemeName] || aa.classes[defaultScheme];
}

function classInfo(schemeName, key) {
    const list = scheme(schemeName).classes;
    for (let i = 0; i < list.length; i++) {
        if (list[i].key === key)
            return list[i];
    }
    return list[0];
}

// ── The amino acids ──────────────────────────────────────────────────────────
//
// mw       free amino acid, g·mol⁻¹
// residue  mass added to a polypeptide chain (mw − H₂O), g·mol⁻¹
// pKa      { cooh: α-COOH, nh3: α-NH₃⁺, side: side chain or null }
// kd       Kyte-Doolittle hydropathy index
// essential  "yes" | "conditional" | "no" | "special"

const aminoAcids = [
    {
        name: "Glycine",
        three: "Gly",
        one: "G",
        mw: 75.07,
        residue: 57.05,
        formula: "C₂H₅NO₂",
        pKa: { cooh: 2.34, nh3: 9.60, side: null },
        pI: 5.97,
        kd: -0.4,
        codons: ["GGU", "GGC", "GGA", "GGG"],
        essential: "conditional",
        classes: { five: "nonpolar", seven: "aliphatic", four: "special" },
        note: "Only achiral proteinogenic amino acid; inhibitory neurotransmitter in the spinal cord and brainstem, and an obligatory co-agonist at the NMDA receptor glycine site.",
        structure: sGly()
    },
    {
        name: "Alanine",
        three: "Ala",
        one: "A",
        mw: 89.09,
        residue: 71.08,
        formula: "C₃H₇NO₂",
        pKa: { cooh: 2.34, nh3: 9.69, side: null },
        pI: 6.01,
        kd: 1.8,
        codons: ["GCU", "GCC", "GCA", "GCG"],
        essential: "no",
        classes: { five: "nonpolar", seven: "aliphatic", four: "hydrophobic" },
        note: "Carries amino nitrogen from muscle to liver in the glucose–alanine cycle; strong helix former.",
        structure: sAla()
    },
    {
        name: "Valine",
        three: "Val",
        one: "V",
        mw: 117.15,
        residue: 99.13,
        formula: "C₅H₁₁NO₂",
        pKa: { cooh: 2.32, nh3: 9.62, side: null },
        pI: 5.97,
        kd: 4.2,
        codons: ["GUU", "GUC", "GUA", "GUG"],
        essential: "yes",
        classes: { five: "nonpolar", seven: "aliphatic", four: "hydrophobic" },
        note: "Branched-chain amino acid; a Glu6→Val substitution in β-globin causes sickle cell disease.",
        structure: sVal()
    },
    {
        name: "Leucine",
        three: "Leu",
        one: "L",
        mw: 131.17,
        residue: 113.16,
        formula: "C₆H₁₃NO₂",
        pKa: { cooh: 2.36, nh3: 9.60, side: null },
        pI: 5.98,
        kd: 3.8,
        codons: ["UUA", "UUG", "CUU", "CUC", "CUA", "CUG"],
        essential: "yes",
        classes: { five: "nonpolar", seven: "aliphatic", four: "hydrophobic" },
        note: "Purely ketogenic; sensed by Sestrin2 to activate mTORC1 and drive protein synthesis.",
        structure: sLeu()
    },
    {
        name: "Isoleucine",
        three: "Ile",
        one: "I",
        mw: 131.17,
        residue: 113.16,
        formula: "C₆H₁₃NO₂",
        pKa: { cooh: 2.36, nh3: 9.68, side: null },
        pI: 6.02,
        kd: 4.5,
        codons: ["AUU", "AUC", "AUA"],
        essential: "yes",
        classes: { five: "nonpolar", seven: "aliphatic", four: "hydrophobic" },
        note: "Two stereocentres (2S,3S); most hydrophobic residue on the Kyte-Doolittle scale.",
        structure: sIle()
    },
    {
        name: "Proline",
        three: "Pro",
        one: "P",
        mw: 115.13,
        residue: 97.12,
        formula: "C₅H₉NO₂",
        pKa: { cooh: 1.99, nh3: 10.96, side: null },
        pI: 6.48,
        kd: -1.6,
        codons: ["CCU", "CCC", "CCA", "CCG"],
        essential: "conditional",
        classes: { five: "nonpolar", seven: "aliphatic", four: "special" },
        note: "Secondary amine locked in a pyrrolidine ring: no backbone amide H, so it breaks α-helices and forms turns; hydroxylated to 4-Hyp in collagen.",
        structure: sPro()
    },
    {
        name: "Methionine",
        three: "Met",
        one: "M",
        mw: 149.21,
        residue: 131.19,
        formula: "C₅H₁₁NO₂S",
        pKa: { cooh: 2.28, nh3: 9.21, side: null },
        pI: 5.74,
        kd: 1.9,
        codons: ["AUG"],
        essential: "yes",
        classes: { five: "nonpolar", seven: "sulfur", four: "hydrophobic" },
        note: "Universal initiator residue (AUG); precursor of S-adenosylmethionine, the cell's main methyl donor.",
        structure: sMet()
    },
    {
        name: "Phenylalanine",
        three: "Phe",
        one: "F",
        mw: 165.19,
        residue: 147.18,
        formula: "C₉H₁₁NO₂",
        pKa: { cooh: 1.83, nh3: 9.13, side: null },
        pI: 5.48,
        kd: 2.8,
        codons: ["UUU", "UUC"],
        essential: "yes",
        classes: { five: "aromatic", seven: "aromatic", four: "hydrophobic" },
        note: "Hydroxylated to tyrosine by phenylalanine hydroxylase; accumulates in phenylketonuria.",
        structure: sPhe()
    },
    {
        name: "Tyrosine",
        three: "Tyr",
        one: "Y",
        mw: 181.19,
        residue: 163.18,
        formula: "C₉H₁₁NO₃",
        pKa: { cooh: 2.20, nh3: 9.11, side: 10.07 },
        pI: 5.66,
        kd: -1.3,
        codons: ["UAU", "UAC"],
        essential: "conditional",
        classes: { five: "aromatic", seven: "aromatic", four: "hydrophobic" },
        note: "Precursor of L-DOPA, dopamine, noradrenaline, adrenaline, melanin and thyroid hormones; major kinase phosphorylation site.",
        structure: sTyr()
    },
    {
        name: "Tryptophan",
        three: "Trp",
        one: "W",
        mw: 204.23,
        residue: 186.21,
        formula: "C₁₁H₁₂N₂O₂",
        pKa: { cooh: 2.38, nh3: 9.39, side: null },
        pI: 5.89,
        kd: -0.9,
        codons: ["UGG"],
        essential: "yes",
        classes: { five: "aromatic", seven: "aromatic", four: "hydrophobic" },
        note: "Largest residue and the main source of protein absorbance at 280 nm; precursor of serotonin and melatonin, and of NAD⁺ via the kynurenine pathway.",
        structure: sTrp()
    },
    {
        name: "Serine",
        three: "Ser",
        one: "S",
        mw: 105.09,
        residue: 87.08,
        formula: "C₃H₇NO₃",
        pKa: { cooh: 2.21, nh3: 9.15, side: null },
        pI: 5.68,
        kd: -0.8,
        codons: ["UCU", "UCC", "UCA", "UCG", "AGU", "AGC"],
        essential: "no",
        classes: { five: "polar", seven: "hydroxylic", four: "polar" },
        note: "Phosphorylation site and serine-protease nucleophile; converted by serine racemase to D-serine, the principal NMDA receptor co-agonist in the forebrain.",
        structure: sSer()
    },
    {
        name: "Threonine",
        three: "Thr",
        one: "T",
        mw: 119.12,
        residue: 101.10,
        formula: "C₄H₉NO₃",
        pKa: { cooh: 2.11, nh3: 9.62, side: null },
        pI: 5.87,
        kd: -0.7,
        codons: ["ACU", "ACC", "ACA", "ACG"],
        essential: "yes",
        classes: { five: "polar", seven: "hydroxylic", four: "polar" },
        note: "Two stereocentres (2S,3R); phosphorylation and O-linked glycosylation site.",
        structure: sThr()
    },
    {
        name: "Cysteine",
        three: "Cys",
        one: "C",
        mw: 121.16,
        residue: 103.14,
        formula: "C₃H₇NO₂S",
        pKa: { cooh: 1.96, nh3: 10.28, side: 8.18 },
        pI: 5.07,
        kd: 2.5,
        codons: ["UGU", "UGC"],
        essential: "conditional",
        classes: { five: "polar", seven: "sulfur", four: "special" },
        note: "Thiol pairs into disulfide bridges that staple secreted proteins; rate-limiting precursor of glutathione. R by CIP but still L.",
        structure: sCys()
    },
    {
        name: "Asparagine",
        three: "Asn",
        one: "N",
        mw: 132.12,
        residue: 114.10,
        formula: "C₄H₈N₂O₃",
        pKa: { cooh: 2.02, nh3: 8.80, side: null },
        pI: 5.41,
        kd: -3.5,
        codons: ["AAU", "AAC"],
        essential: "no",
        classes: { five: "polar", seven: "amidic", four: "polar" },
        note: "Acceptor of N-linked glycans at the Asn-X-Ser/Thr sequon; first amino acid isolated (asparagus, 1806).",
        structure: sAsn()
    },
    {
        name: "Glutamine",
        three: "Gln",
        one: "Q",
        mw: 146.15,
        residue: 128.13,
        formula: "C₅H₁₀N₂O₃",
        pKa: { cooh: 2.17, nh3: 9.13, side: null },
        pI: 5.65,
        kd: -3.5,
        codons: ["CAA", "CAG"],
        essential: "conditional",
        classes: { five: "polar", seven: "amidic", four: "polar" },
        note: "Most abundant free amino acid in blood; astrocytes recycle synaptic glutamate through the glutamate–glutamine cycle. CAG expansions cause polyQ diseases.",
        structure: sGln()
    },
    {
        name: "Aspartic acid",
        three: "Asp",
        one: "D",
        mw: 133.10,
        residue: 115.09,
        formula: "C₄H₇NO₄",
        pKa: { cooh: 1.88, nh3: 9.60, side: 3.65 },
        pI: 2.77,
        kd: -3.5,
        codons: ["GAU", "GAC"],
        essential: "no",
        classes: { five: "acidic", seven: "chargedNeg", four: "charged" },
        note: "Nitrogen donor in the urea cycle and in purine synthesis; its D-isomer is a neuroendocrine signalling molecule.",
        structure: sAsp()
    },
    {
        name: "Glutamic acid",
        three: "Glu",
        one: "E",
        mw: 147.13,
        residue: 129.12,
        formula: "C₅H₉NO₄",
        pKa: { cooh: 2.19, nh3: 9.67, side: 4.25 },
        pI: 3.22,
        kd: -3.5,
        codons: ["GAA", "GAG"],
        essential: "no",
        classes: { five: "acidic", seven: "chargedNeg", four: "charged" },
        note: "Principal excitatory neurotransmitter of the CNS; decarboxylated by GAD to GABA, the principal inhibitory one.",
        structure: sGlu()
    },
    {
        name: "Histidine",
        three: "His",
        one: "H",
        mw: 155.15,
        residue: 137.14,
        formula: "C₆H₉N₃O₂",
        pKa: { cooh: 1.82, nh3: 9.17, side: 6.00 },
        pI: 7.59,
        kd: -3.2,
        codons: ["CAU", "CAC"],
        essential: "yes",
        classes: { five: "basic", seven: "chargedPos", four: "charged" },
        note: "Imidazole pKa ≈ 6 is the only side chain that titrates near pH 7, making it the universal acid–base catalyst and buffer; precursor of histamine.",
        structure: sHis()
    },
    {
        name: "Lysine",
        three: "Lys",
        one: "K",
        mw: 146.19,
        residue: 128.17,
        formula: "C₆H₁₄N₂O₂",
        pKa: { cooh: 2.18, nh3: 8.95, side: 10.53 },
        pI: 9.74,
        kd: -3.9,
        codons: ["AAA", "AAG"],
        essential: "yes",
        classes: { five: "basic", seven: "chargedPos", four: "charged" },
        note: "ε-amine is the target of acetylation, methylation, SUMOylation and ubiquitination — the core of the histone code.",
        structure: sLys()
    },
    {
        name: "Arginine",
        three: "Arg",
        one: "R",
        mw: 174.20,
        residue: 156.19,
        formula: "C₆H₁₄N₄O₂",
        pKa: { cooh: 2.17, nh3: 9.04, side: 12.48 },
        pI: 10.76,
        kd: -4.5,
        codons: ["CGU", "CGC", "CGA", "CGG", "AGA", "AGG"],
        essential: "conditional",
        classes: { five: "basic", seven: "chargedPos", four: "charged" },
        note: "Guanidinium stays protonated at every physiological pH; substrate of nitric oxide synthase and hub of the urea cycle.",
        structure: sArg()
    },
    {
        name: "Selenocysteine",
        three: "Sec",
        one: "U",
        mw: 168.05,
        residue: 150.04,
        formula: "C₃H₇NO₂Se",
        pKa: { cooh: 1.91, nh3: 10.0, side: 5.2 },
        pKaApprox: true,
        pI: null,
        kd: null,
        codons: ["UGA"],
        essential: "special",
        classes: { five: "polar", seven: "sulfur", four: "special" },
        note: "21st amino acid: read through a UGA stop codon when a SECIS element is present. The selenol is far more reactive than a thiol at pH 7 — active site of glutathione peroxidases and deiodinases.",
        structure: sSec()
    },
    {
        name: "Pyrrolysine",
        three: "Pyl",
        one: "O",
        mw: 255.31,
        residue: 237.30,
        formula: "C₁₂H₂₁N₃O₃",
        pKa: { cooh: null, nh3: null, side: null },
        pI: null,
        kd: null,
        codons: ["UAG"],
        essential: "special",
        classes: { five: "basic", seven: "amidic", four: "special" },
        note: "22nd amino acid: a UAG stop codon recoded by a PYLIS element in methanogenic archaea and a few bacteria. Sits in the active site of methylamine methyltransferases.",
        structure: sPyl()
    }
];

// ── Genetic code ─────────────────────────────────────────────────────────────

const bases = ["U", "C", "A", "G"];

const geneticCode = {
    UUU: "F", UUC: "F", UUA: "L", UUG: "L",
    UCU: "S", UCC: "S", UCA: "S", UCG: "S",
    UAU: "Y", UAC: "Y", UAA: "*", UAG: "*",
    UGU: "C", UGC: "C", UGA: "*", UGG: "W",
    CUU: "L", CUC: "L", CUA: "L", CUG: "L",
    CCU: "P", CCC: "P", CCA: "P", CCG: "P",
    CAU: "H", CAC: "H", CAA: "Q", CAG: "Q",
    CGU: "R", CGC: "R", CGA: "R", CGG: "R",
    AUU: "I", AUC: "I", AUA: "I", AUG: "M",
    ACU: "T", ACC: "T", ACA: "T", ACG: "T",
    AAU: "N", AAC: "N", AAA: "K", AAG: "K",
    AGU: "S", AGC: "S", AGA: "R", AGG: "R",
    GUU: "V", GUC: "V", GUA: "V", GUG: "V",
    GCU: "A", GCC: "A", GCA: "A", GCG: "A",
    GAU: "D", GAC: "D", GAA: "E", GAG: "E",
    GGU: "G", GGC: "G", GGA: "G", GGG: "G"
};

// Codons recoded to Sec / Pyl only in the presence of a downstream element.
const recoded = { UGA: "U", UAG: "O" };

const byLetter = (function () {
    const m = {};
    for (let i = 0; i < aminoAcids.length; i++)
        m[aminoAcids[i].one] = aminoAcids[i];
    return m;
})();

function lookup(letter) {
    return byLetter[letter] || null;
}

// Rows of the classic 4×4×4 codon table: 16 rows of 4 cells, first base varying
// slowest. Each cell is { codon, letter, three, name, stop }.
function codonRows() {
    const rows = [];
    for (let i = 0; i < 4; i++) {
        for (let j = 0; j < 4; j++) {
            const cells = [];
            for (let k = 0; k < 4; k++) {
                const codon = bases[i] + bases[j] + bases[k];
                const letter = geneticCode[codon];
                const aa = lookup(letter);
                cells.push({
                    codon: codon,
                    letter: letter,
                    three: aa ? aa.three : "Stop",
                    name: aa ? aa.name : "Stop codon",
                    stop: letter === "*",
                    recoded: recoded[codon] || ""
                });
            }
            rows.push({
                first: bases[i],
                second: bases[j],
                cells: cells
            });
        }
    }
    return rows;
}

// ── Search ───────────────────────────────────────────────────────────────────

function searchBlob(aa, schemeName) {
    return [
        aa.name,
        aa.three,
        aa.one,
        aa.formula,
        classInfo(schemeName, classOf(aa, schemeName)).name,
        aa.codons.join(" "),
        aa.note
    ].join(" ").toLowerCase();
}
