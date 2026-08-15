import qs.modules.ii.overview

// Tablet-specific overview entry point.
// The existing ii overview already auto-scales workspace previews from the
// available screen geometry, so the first tablet iteration deliberately keeps
// that implementation intact. Tablet-only layout/touch changes can be layered
// here later without forking Overview.qml.
Overview {}
