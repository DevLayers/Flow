import qs.modules.ii.bar

// Tablet-specific entry point for the horizontal bar.
// Keep the ii implementation as the source of truth; tablet-only sizing and
// interaction overrides belong here instead of forking the complete bar tree.
Bar {
    sizeScale: 1.22
}
