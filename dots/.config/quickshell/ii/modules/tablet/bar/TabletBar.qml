import qs.modules.ii.bar

// Tablet-specific entry point for the horizontal bar.
//
// Only the top pinning is tablet-specific. An earlier sizeScale grew the bar *window* while
// every widget inside still sized itself off the unscaled Appearance.sizes.barHeight, which
// left the group backgrounds, hit targets and popup anchors all measuring against a bar that
// was 22% taller than they thought — widgets lost their background, shrank, or vanished.
Bar {
    forceTop: true
}
