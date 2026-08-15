# ii Dock Live Preview — Implementation Plan

**Repository:** `P3DROVFX/ii-p3drovfx`  
**Target branch:** `dev`  
**Feature:** Dock **Live Preview Widget**  
**Primary stack:** Quickshell + Hyprland + `ScreencopyView`  
**Reference concept:** attached macOS Dynamic Dock concept image  
**Main design rule:** one live screencopy stream at a time, active only while the preview is actually visible.

---

# 1. Objective

Add a new optional Dock widget:

```text
Live Preview
```

The widget displays a **live preview of one selected application window** directly inside the Dock.

Example:

```text
╭──────────────────────────────────╮
│ ┌───────────────┐                │
│ │               │  Figma        │
│ │  LIVE WINDOW  │  project.fig  │
│ │               │          ↗  ▾ │
│ └───────────────┘                │
╰──────────────────────────────────╯
```

The selected application is chosen directly from Dock UI.

The preview should be live only while it is useful:

```text
Dock visible
+
Live Preview visible
+
valid selected window
        ↓
capture active
```

Otherwise:

```text
captureSource = null
```

No persistent background stream.

---

# 2. Non-goals

Do **not** implement in v1:

- a full recent-activity browser above the Dock;
- multiple simultaneous live previews;
- live thumbnails for every app in the picker;
- PipeWire capture;
- xdg-desktop-portal capture;
- OBS integration;
- FFmpeg capture;
- QtMultimedia;
- window screenshots written to disk continuously;
- custom compositor plugin;
- custom Hyprland screencopy client;
- blur-heavy preview pipeline;
- animated mask morph;
- app-window screenshot morph from Dock icon;
- remote applications;
- preview recording.

Keep the feature centered on:

```text
1 selected app
1 selected toplevel
1 ScreencopyView
```

---

# 3. Why the feature is viable

The ii Dock already uses:

```text
Quickshell.Wayland.ScreencopyView
```

inside:

```text
modules/ii/dock/widgets/DockPreviewPopup.qml
```

Current architecture already proves:

```text
Toplevel
   ↓
ScreencopyView
   ↓
live preview
```

and already uses the important lifecycle pattern:

```qml
captureSource: previewPopup.visible
    ? windowButton.modelData
    : null
```

The new widget should reuse the same Quickshell screencopy mechanism rather than introducing another capture stack.

---

# 4. Current Dock lifecycle relevant to capture

The Dock is not fully destroyed or made invisible every time auto-hide hides it.

Current state is primarily controlled by:

```text
dockRoot.reveal
```

while the Dock surface moves using its hidden offset.

Therefore:

```text
dockRoot.visible
```

is **not sufficient** to decide whether live capture should run.

Correct capture lifecycle must depend on:

```text
dockRoot.reveal
```

plus widget visibility.

---

# 5. Core architecture

```text
                         Dock.qml
                            │
                      dockRoot.reveal
                            │
                            ▼
                    DockContent.qml
                            │
                 type: "livePreview"
                            │
                            ▼
               DockLivePreviewWidget.qml
                            │
                 ┌──────────┴───────────┐
                 │                      │
        LivePreviewService       visual component
                 │                      │
                 ▼                      ▼
        selected app/window        ScreencopyView
                 │                      │
                 └──────────┬───────────┘
                            ▼
                      captureActive
                            │
               ┌────────────┴────────────┐
               │                         │
             true                       false
               │                         │
               ▼                         ▼
       captureSource=Toplevel      captureSource=null
```

---

# 6. Proposed new files

Add:

```text
dots/.config/quickshell/ii/services/DockLivePreviewService.qml
```

Add:

```text
dots/.config/quickshell/ii/modules/ii/dock/DockLivePreviewWidget.qml
```

Add:

```text
dots/.config/quickshell/ii/modules/ii/dock/widgets/DockLivePreviewPicker.qml
```

Optional, only if needed:

```text
dots/.config/quickshell/ii/modules/ii/dock/widgets/DockLivePreviewPlaceholder.qml
```

Prefer keeping placeholder UI inside the main widget unless it becomes large.

---

# 7. Existing files expected to change

Primary:

```text
dots/.config/quickshell/ii/modules/common/Config.qml
dots/.config/quickshell/ii/modules/common/Appearance.qml

dots/.config/quickshell/ii/modules/ii/dock/Dock.qml
dots/.config/quickshell/ii/modules/ii/dock/DockContent.qml
dots/.config/quickshell/ii/modules/ii/dock/DockAppButton.qml
dots/.config/quickshell/ii/modules/ii/dock/widgets/DockContextMenu.qml

dots/.config/quickshell/ii/modules/settings/configs/DockConfig.qml
```

Potential integration files:

```text
DockWidgetStack.qml
DockIslandSurface.qml / island segmentation code
TaskbarApps.qml
```

depending on implementation order of the previously planned Dock features.

---

# 8. Config schema

Add under:

```text
Config.options.dock
```

recommended fields:

```qml
property bool enableLivePreviewWidget: false
property string livePreviewAppId: ""
property int livePreviewSlots: 4
property bool livePreviewPaintCursor: false
property string livePreviewCaptureMode: "visible"
property bool livePreviewFollowActiveWindow: true
```

Supported capture modes initially:

```text
"visible"
"hover"
```

---

# 9. Config semantics

## `enableLivePreviewWidget`

Controls whether the Dock item exists.

Default:

```text
false
```

---

## `livePreviewAppId`

Persistent preferred application.

Example:

```text
"com.spotify.Client"
"figma-linux"
"firefox"
```

Store an **application identity**, not a specific Toplevel pointer.

---

## `livePreviewSlots`

Horizontal widget width.

Recommended default:

```text
4
```

Minimum:

```text
3
```

Recommended Settings range:

```text
3–6
```

---

## `livePreviewPaintCursor`

Whether the captured app cursor is painted.

Recommended default:

```text
false
```

A tiny Dock preview usually does not benefit from showing the cursor.

---

## `livePreviewCaptureMode`

```text
visible
```

means:

```text
capture while Dock + widget are visible
```

```text
hover
```

means:

```text
capture only while user hovers Live Preview
```

---

## `livePreviewFollowActiveWindow`

When an application has multiple windows:

```text
true:
    follow its most recently activated/current active Toplevel

false:
    use runtime locked Toplevel if one is selected
```

Default:

```text
true
```

---

# 10. Runtime state belongs outside Config

Do not persist:

```text
selectedToplevel object
captureReady
captureActive
pickerOpen
lockedWindow
lastCaptureError
```

These are runtime-only.

Keep them in:

```text
DockLivePreviewService.qml
```

or local widget state.

---

# 11. Optional Persistent state

If desired, store:

```text
lastSelectedWindowTitle
```

only for visual hinting.

Do **not** use it as a stable identity.

Toplevel titles are not reliable persistent window IDs.

Prefer no Persistent state in v1.

---

# 12. Dock model integration

Add a new flattened item type:

```js
{
    type: "livePreview",
    orderKey: "livePreview"
}
```

---

# 13. Default Dock order

Extend the default order with:

```text
livePreview
```

near other widgets:

```text
media
weather
sports
livePreview
phone
```

Because the feature is disabled by default, old/new users see no additional item until enabled.

---

# 14. Compatibility with old saved `dock.order`

Existing users may have an order created before `livePreview` exists.

Follow the same compatibility strategy already used by newer Dock items:

if:

```text
enableLivePreviewWidget == true
```

and:

```text
dock.order does not contain "livePreview"
```

insert it automatically near other widgets without rewriting the whole user order.

A later drag persists its explicit position.

---

# 15. Item category

Add to:

```text
getItemCategory()
```

as a widget/media-like category.

Suggested:

```text
livePreview → around media/weather widget range
```

Do not categorize it as app.

---

# 16. Special item behavior

Add:

```text
livePreview
```

to:

```text
isSpecialItem()
```

for classic divider logic.

If Islands Style is active, divider behavior follows the Islands policy.

---

# 17. Main-axis extent

Horizontal:

```text
livePreview width =
    buttonSlotSize * Config.options.dock.livePreviewSlots
```

Vertical:

use a compact orientation-specific layout.

Do not use 4 vertical slots blindly.

---

# 18. Magnification

Live Preview is a wide widget.

It must be:

```text
magnifiable = false
```

Update:

```text
_isMagnifiableItem()
```

accordingly.

---

# 19. Base metrics

Ensure:

```text
_rawItemMainExtent()
```

understands:

```text
type: "livePreview"
```

so:

- dynamic Dock width;
- PanelWindow safety;
- drag;
- Flickable;
- Islands geometry

all receive the correct size.

---

# 20. Service responsibilities

`DockLivePreviewService.qml` should own:

```text
preferredAppId
resolvedApp
candidateToplevels
selectedToplevel
followActiveWindow
lockedToplevel
captureLifecycle state
```

It should not draw UI.

---

# 21. Service inputs

The service can use:

```text
TaskbarApps.apps
ToplevelManager
Config.options.dock.livePreviewAppId
```

Reuse existing Dock/Taskbar application identity logic.

---

# 22. Application resolution

Preferred route:

```text
Config.livePreviewAppId
        ↓
TaskbarApps.normalizeAppId()
        ↓
TaskbarApps.apps
        ↓
matching application
```

Match using the same normalized identity logic already used by the Dock.

Do not create a separate incompatible app-ID normalization scheme.

---

# 23. App not present in TaskbarApps

If a persisted selected app is not currently running:

attempt to resolve its DesktopEntry from cache.

State:

```text
selected app known
window unavailable
```

Widget stays usable as a launcher.

---

# 24. Toplevel resolution

From the matched app:

```text
app.toplevels
```

or corresponding current TaskbarApps property.

Candidate windows:

```text
0:
    no live source

1:
    use that window

>1:
    follow active / runtime lock
```

---

# 25. Default multi-window policy

Default:

```text
followActiveWindow = true
```

Resolution priority:

1. currently activated window for the app;
2. most recently activated if available;
3. first valid toplevel.

---

# 26. Window lock mode

The picker may let the user select one specific current window.

This sets:

```text
lockedToplevel
```

runtime only.

Do not persist pointer/object identity.

---

# 27. Locked window closes

Immediately:

```text
lockedToplevel = null
```

Then:

```text
followActiveWindow fallback
```

No error popup.

---

# 28. App closes

Service state:

```text
resolved app identity retained
selectedToplevel = null
```

Widget transitions to:

```text
Not running
```

placeholder.

---

# 29. App restarts

TaskbarApps/Toplevel changes naturally resolve a new window.

No polling.

When a valid Toplevel appears:

```text
placeholder
    ↓
capture starts if allowed
    ↓
preview fades in
```

---

# 30. Capture lifecycle

Define one explicit property:

```text
captureRequested
```

Conceptually:

```qml
captureRequested =
    featureEnabled
    && dockActuallyShown
    && widgetActuallyVisible
    && selectedToplevel !== null
    && captureModeCondition
```

---

# 31. `dockActuallyShown`

Pass from Dock/DockContent:

```text
dockRoot.reveal
```

not merely:

```text
dockRoot.visible
```

---

# 32. `widgetActuallyVisible`

Classic Dock:

```text
Live Preview item exists and is inside visible Dock
```

Widgets Stack:

```text
Live Preview page is current
```

Potential Flickable optimization later:

```text
only capture if item is inside viewport
```

Not necessary for v1 unless dense Dock testing shows need.

---

# 33. Capture mode condition

For:

```text
visible
```

condition:

```text
true
```

For:

```text
hover
```

condition:

```text
widgetHover.hovered
```

---

# 34. Final capture source

Inside widget:

```qml
ScreencopyView {
    captureSource:
        root.captureActive
            ? DockLivePreviewService.selectedToplevel
            : null

    live: true
}
```

---

# 35. No idle live stream

When:

```text
captureActive = false
```

source must be exactly:

```text
null
```

Do not keep:

```text
live = false
source = Toplevel
```

as the normal idle strategy.

Release the source.

---

# 36. Capture start

When Dock reveal begins:

```text
reveal false → true
```

activate source immediately.

This lets the compositor begin delivering frames while the Dock itself animates into view.

---

# 37. Capture stop timing

Do not stop source on the exact first frame of Dock hide.

Use a short one-shot teardown delay aligned with Dock hide motion.

Recommended starting target:

```text
180–240 ms
```

Flow:

```text
reveal false
    ↓
Dock slide-out starts
    ↓
preview remains last/live during exit
    ↓
teardown timer
    ↓
captureSource=null
```

---

# 38. No polling Timer

The teardown Timer is:

```text
single-shot lifecycle delay
```

not recurring polling.

This is acceptable.

Do not use a repeating capture-management Timer.

---

# 39. Capture cancellation

If Dock is revealed again before teardown fires:

```text
cancel teardown
keep source active
```

This avoids disconnect/reconnect churn during quick pointer movements.

---

# 40. `hasContent`

Use:

```text
ScreencopyView.hasContent
```

to decide when the live frame is visually ready.

States:

```text
capture requested
hasContent false
    ↓
loading / app identity placeholder

hasContent true
    ↓
preview enters
```

---

# 41. First-frame placeholder

Before capture frame is ready:

```text
╭──────────────────────────────╮
│     [app icon]               │
│     Figma                    │
│     Connecting preview...    │
╰──────────────────────────────╯
```

No generic spinner required if it looks too busy.

A subtle animated shimmer/opacity pulse is enough.

---

# 42. Capture stopped signal

If ScreencopyView signals that capture stopped:

```text
captureReady = false
```

transition to:

```text
Preview unavailable
```

Do not immediately enter a retry loop.

---

# 43. Retry policy

Reconnect only after a meaningful event:

```text
Dock hide → show
selected window changes
app restarts
selection changes
capture mode changes
```

No retry every second.

---

# 44. Protected/no-share windows

If the compositor refuses/protects a window:

show:

```text
Preview unavailable
```

plus app icon/name.

Do not attempt to bypass the compositor's sharing rules.

---

# 45. Widget visual architecture

Recommended:

```text
DockLivePreviewWidget
│
├── background
├── previewFrame
│     └── ClippingRectangle
│           └── ScreencopyView
│
├── metadataColumn
│     ├── app name
│     └── window title
│
├── hoverControls
│     ├── focus
│     └── picker
│
└── placeholder states
```

---

# 46. Widget layout

Horizontal default:

```text
╭────────────────────────────────────╮
│ ┌──────────────┐                   │
│ │              │  Figma       ↗ ▾ │
│ │ live preview │  Homepage.fig    │
│ │              │                  │
│ └──────────────┘                   │
╰────────────────────────────────────╯
```

---

# 47. Preview width ratio

Do not force the captured window to fill the entire widget.

Recommended:

```text
preview = ~45–55% of widget width
metadata = remaining width
```

This preserves recognizable 16:9-ish content without extreme crop.

---

# 48. Preview aspect behavior

Prefer:

```text
preserve aspect ratio
```

with controlled crop/background.

Do not stretch 16:9 windows into arbitrary Dock proportions.

---

# 49. Crop strategy

Recommended:

```text
PreserveAspectCrop
```

or equivalent if ScreencopyView supports appropriate fill semantics through its sizing/container.

If not directly supported:

constrain the ScreencopyView and clip overflowing content.

Avoid custom shader scaling.

---

# 50. Rounded clipping

Prefer:

```text
ClippingRectangle
```

around the preview.

Do not use `OpacityMask` unless the current Qt version or Quickshell build makes `ClippingRectangle` unavailable/incompatible.

This feature should avoid adding mask complexity where possible.

---

# 51. Widget background

Reuse current Dock widget material:

```text
Appearance colors
Config.options.dock.widgetRadius
```

No Live Preview-specific hard-coded color.

---

# 52. Preview frame background

When no capture content:

```text
colSurfaceContainer / transparentized layer
```

Use standard design tokens.

---

# 53. App icon

Show small app icon:

- during placeholder;
- optionally near metadata;
- during transitions.

Use the same DesktopEntry icon system already used by DockAppButton.

---

# 54. Window title

Use:

```text
selectedToplevel.title
```

with:

```text
Text.ElideRight
```

Do not let a long page/document title change widget width.

---

# 55. App name

Use DesktopEntry name as primary label.

Example:

```text
Figma
Homepage.fig
```

---

# 56. Main click

Clicking non-control preview area:

```text
selectedToplevel.activate()
```

If no running window:

```text
DesktopEntry.execute()
```

---

# 57. Focus button

Small:

```text
↗
```

button performs the same focus action explicitly.

It may be hidden until hover.

---

# 58. Picker button

Small:

```text
▾
```

opens:

```text
DockLivePreviewPicker
```

---

# 59. Right click

Right click may open a Live Preview-specific small menu:

```text
Change preview
Follow active window
Stop preview
```

Do not reuse full app context menu unless useful.

---

# 60. Middle click

Recommended:

```text
toggle capture mode visible ↔ hover
```

is too hidden/unexpected.

Keep middle-click unassigned in v1.

---

# 61. Hover controls

Normal state:

```text
controls opacity ~0
```

Hover:

```text
controls opacity → 1
metadata slightly more visible
```

Use short motion:

```text
140–180 ms
```

---

# 62. Hover overlay

Avoid blur.

Use a simple transparent gradient/rectangle if needed for readability over the preview.

No MultiEffect.

---

# 63. Press animation

On preview click:

```text
scale 1.00 → 0.975 → 1.00
```

Target:

```text
~100–140 ms
```

Use standard button press behavior where possible.

---

# 64. Widget insertion animation

When Live Preview is enabled:

main-axis extent:

```text
0 / compact slot
    ↓
configured widget width
```

opacity:

```text
0 → 1
```

scale:

```text
0.95 → 1
```

Recommended visual settle:

```text
~300–380 ms
```

---

# 65. Widget removal animation

Reverse:

```text
width collapses
opacity fades
content scale slightly down
```

Do not instantly destroy if model architecture can preserve it during exit.

If Repeater destruction makes true exit difficult, prioritize smooth layout movement over elaborate exit lifecycle.

---

# 66. Preview first-frame animation

When:

```text
hasContent false → true
```

animate:

```text
preview opacity 0 → 1
preview scale .97 → 1
```

while placeholder:

```text
opacity 1 → 0
```

Recommended:

```text
180–240 ms
```

---

# 67. Preview source change animation

When selected app/window changes:

Phase 1:

```text
old preview
y: 0 → -6/-10
opacity: 1 → 0
scale: 1 → 1.02
```

Then change source.

Phase 2:

wait:

```text
hasContent
```

New preview:

```text
y: +6/+10 → 0
opacity: 0 → 1
scale: .97 → 1
```

---

# 68. No hard cut

Never directly change:

```text
captureSource A → B
```

while the visible old frame remains fully opaque.

Gate source transition through widget state.

---

# 69. Source transition state machine

Recommended:

```text
stable
exitingOld
waitingForFrame
enteringNew
```

Properties:

```text
displayedToplevel
pendingToplevel
transitionPhase
```

---

# 70. Source transition sequence

```text
new selectedToplevel
    ↓
pending = new
    ↓
fade/slide old
    ↓
displayedToplevel = pending
    ↓
captureSource updates
    ↓
hasContent
    ↓
animate new in
    ↓
stable
```

---

# 71. Rapid selection changes

If user quickly chooses multiple apps:

```text
pendingToplevel = latest
```

Do not queue every intermediate target.

After current exit:

switch directly to latest pending selection.

---

# 72. Window close animation

If current window closes:

```text
preview fade/scale out
    ↓
placeholder app identity fades in
```

If another Toplevel of same app exists and follow-active is enabled:

transition directly to that window instead.

---

# 73. App launch transition

App not running:

```text
placeholder
```

Click:

```text
execute app
```

When first Toplevel appears:

```text
connecting state
    ↓
hasContent
    ↓
live preview enters
```

---

# 74. Picker UX

Keep picker simple.

Do not reproduce the reference's large vertical content stack.

Recommended popup:

```text
╭────────────────────────────╮
│ Live Preview               │
│                            │
│ Search...                  │
│                            │
│ Figma        Homepage.fig  │
│ Firefox      GitHub        │
│ Kitty        ~/project     │
│ Dolphin      Downloads     │
│                            │
│ Clear preview              │
╰────────────────────────────╯
```

---

# 75. Picker source

Use current running Dock/Toplevel data.

No screencopies inside picker.

Rows contain only:

```text
icon
app name
window title
active indicator
```

---

# 76. Picker search

Optional but low-cost.

Search:

```text
app name
window title
```

If implementation becomes large, omit search in v1.

---

# 77. Picker grouping

Recommended grouping by app:

```text
Figma
  Homepage.fig

Firefox
  GitHub
  ChatGPT
```

But a flat list is acceptable for v1.

---

# 78. App vs window selection

Clicking app-level row:

```text
preferredAppId = appId
followActiveWindow = true
lockedToplevel = null
```

Clicking specific window:

```text
preferredAppId = appId
followActiveWindow = false
lockedToplevel = selected runtime Toplevel
```

---

# 79. Persist only app selection

Specific window lock is runtime-only.

When Quickshell restarts:

```text
preferred app remains
follow active window resumes
```

This avoids stale window identifiers.

---

# 80. Picker animation

Open:

```text
opacity 0 → 1
scale .94 → 1
offset +8 → 0
```

Close:

reverse.

Target:

```text
180–240 ms
```

Use existing popup motion tokens if suitable.

---

# 81. Picker anchor

Anchor to Live Preview widget itself.

Respect:

```text
top
bottom
left
right Dock
```

using the same PopupWindow anchoring patterns already used by Dock previews/tooltips.

---

# 82. Right-click app integration

Add to Dock app context menu:

```text
Show in Live Preview
```

Only show when:

```text
enableLivePreviewWidget
```

or optionally allow it to enable the feature automatically.

Recommended:

if widget disabled:

```text
Set as Live Preview
```

should:

1. enable Live Preview widget;
2. persist appId;
3. select app;
4. reveal widget.

---

# 83. Context-menu behavior

Right click on Figma:

```text
Set as Live Preview
```

Updates:

```text
Config.options.dock.livePreviewAppId
```

If app has multiple windows:

default to follow-active.

---

# 84. Avoid window-specific context-menu persistence

Do not write the selected Toplevel title/address into Config from the normal app menu.

Specific window selection belongs in picker.

---

# 85. Clear preview

Picker/context menu includes:

```text
Clear preview
```

Behavior:

```text
livePreviewAppId = ""
selectedToplevel = null
```

Widget remains enabled but shows:

```text
Choose an app
```

---

# 86. Empty widget state

```text
╭──────────────────────────────╮
│        +                     │
│     Live Preview             │
│     Choose an app            │
╰──────────────────────────────╯
```

Click anywhere:

```text
open picker
```

---

# 87. Empty state animation

Subtle icon pulse or scale:

```text
1.00 ↔ 1.04
```

Only while Dock is visible.

Do not run continuous decorative animation while Dock is hidden.

---

# 88. Capture mode: visible

Flow:

```text
Dock reveal true
widget page visible
valid Toplevel
    ↓
capture starts
```

On pinned Dock:

capture remains live while Dock stays shown.

---

# 89. Capture mode: hover

Normal widget state can display:

```text
last known visual / app identity
```

But since source is released, do not rely on retaining ScreencopyView's texture indefinitely.

Recommended idle:

```text
app identity placeholder
```

Hover:

```text
capture starts
```

---

# 90. Hover mode first-frame UX

On hover:

```text
placeholder
    ↓
capture connects
    ↓
hasContent
    ↓
preview fades in
```

On hover leave:

delay ~100–150 ms before teardown to avoid rapid disconnect on tiny pointer movements.

---

# 91. Do not implement fake FPS throttling

Do not use:

```text
Timer captureFrame() every 66 ms
```

to fake 15 FPS.

Use:

```text
live: true
```

while active and:

```text
captureSource = null
```

while inactive.

The lifecycle is the performance control.

---

# 92. Optional future snapshot mode

A future mode could use:

```text
live: false
captureFrame()
```

to maintain a frozen thumbnail.

Out of scope for v1.

---

# 93. Widgets Stack integration

Add:

```text
livePreview
```

as a stackable page.

Potential pages:

```text
media
weather
sports
livePreview
phone
```

---

# 94. Stack page visibility

Critical optimization:

if current Stack page is not Live Preview:

```text
widgetActuallyVisible = false
captureSource = null
```

Even if Dock itself is visible.

---

# 95. Stack page activation

When user switches to Live Preview:

start capture as page transition begins.

Do not wait for transition completion.

This hides first-frame latency inside page animation.

---

# 96. Stack page deactivation

When leaving Live Preview page:

keep source alive through outgoing page animation.

After page transition completes:

```text
captureSource = null
```

This is better than cutting the stream before the card slides away.

---

# 97. Stack transition integration

Expose from `DockWidgetStack`:

```text
pageActive(key)
pageTransitioningOut(key)
```

or a simpler:

```text
livePreviewVisibilityFactor
```

Use discrete lifecycle events rather than checking opacity continuously.

---

# 98. Stack width

Live Preview preferred width:

```text
4 slots
```

If Stack computes width from max page width, Live Preview may cause stack width to become 4 slots.

This is acceptable.

---

# 99. Islands Style integration

In Islands Style:

```text
livePreview
```

is its own standalone island.

Classification:

```text
kind = "livePreview"
standalone = true
```

---

# 100. Island magnification

Live Preview island remains:

```text
magnifiable = false
```

Its surface can move as adjacent islands expand.

---

# 101. Island width

Island width follows Live Preview widget's real main extent.

No special estimate.

---

# 102. Media App Transform integration

No mutual exclusion needed.

Example:

```text
[ apps ]
[ YouTube Music transformed media widget ]
[ Figma Live Preview ]
```

Both can coexist.

---

# 103. Widgets Stack + Media App Transform

Those two already have their own mutual-exclusion policy from the previous feature plan.

Live Preview does not alter that rule.

If Stack wins:

Live Preview may be inside Stack.

If Media App Transform wins:

Live Preview remains standalone.

---

# 104. Drag/reorder

Live Preview behaves as one Dock item.

It can be dragged/reordered like:

```text
media
weather
sports
phone
```

---

# 105. Persisting reorder

Because:

```text
orderKey = "livePreview"
```

standard Dock reorder can persist its position.

No synthetic-block logic required.

---

# 106. Drag behavior while capture live

Recommended:

when internal Dock drag begins:

```text
captureSource = null
```

Reasons:

- avoid wasting capture while user is rearranging;
- prevent ScreencopyView texture from complicating drag rendering;
- avoid live visual motion inside moving card.

During drag display:

```text
app icon + "Live Preview"
```

placeholder.

---

# 107. Drag end

After drop:

if:

```text
Dock still visible
widget visible
```

restart capture.

---

# 108. External file drag

Disable capture while:

```text
externalDragOver
```

if current Dock architecture makes this easy.

Optional optimization.

Not release-critical.

---

# 109. Context menu

While Live Preview picker/context menu is open:

keep preview capture alive if widget remains visible.

Do not stop source merely because context UI exists.

---

# 110. Auto-hide request

If picker is open:

Live Preview should contribute to:

```text
requestDockShow
```

so Dock does not auto-hide under its own picker.

---

# 111. Picker popup lifecycle

Add picker state to:

```text
DockContent.requestDockShow
```

or route through existing context-menu open counters.

Preferred:

use a dedicated:

```text
livePreviewPickerOpen
```

request.

---

# 112. Window activation

When preview is clicked:

```text
selectedToplevel.activate()
```

Then optionally:

```text
Dock auto-hide proceeds normally
```

No need to force-hide immediately.

---

# 113. Focused selected window

If selected window already focused:

click can still call `activate()` harmlessly.

Optional:

do nothing special.

---

# 114. App selection by context menu

When selecting a Dock app that has:

```text
0 windows
```

but is pinned:

persist appId anyway.

Widget becomes launcher placeholder until it opens.

---

# 115. App groups

Context-menu option for an entire appGroup is ambiguous.

Do not offer:

```text
Set group as Live Preview
```

in v1.

Users select an individual app/window from picker.

---

# 116. Generic running apps group

Same rule.

No group-level preview source.

---

# 117. Multiple monitors

Each Dock instance should display the same configured preferred app, but selected Toplevel resolution should prefer its own monitor.

Recommended priority per Dock instance:

1. selected app Toplevel on current Dock screen;
2. activated selected-app Toplevel;
3. any selected-app Toplevel.

---

# 118. Isolate monitors

When:

```text
dock.isolateMonitors = true
```

prefer only Toplevels shown on that monitor.

If none exist:

widget may show:

```text
Open on another monitor
```

or use global fallback.

Recommended v1:

```text
strict when isolateMonitors = true
```

---

# 119. Per-monitor runtime source

The service may need screen context.

Avoid making one singleton property:

```text
selectedToplevel
```

globally if multiple Dock instances need different window choices.

Recommended split:

```text
DockLivePreviewService
    app identity / candidate helpers

DockLivePreviewWidget
    current-screen selected Toplevel
```

---

# 120. Service singleton responsibility

Singleton owns:

```text
preferred app
candidate helpers
matching functions
```

Each widget instance derives:

```text
selected Toplevel for its currentScreen
```

This prevents cross-monitor source conflict.

---

# 121. Performance

Expected capture count:

Classic, one Dock screen:

```text
1 active stream max
```

Multiple visible Dock instances:

potentially:

```text
1 per visible monitor
```

if each renders the widget.

---

# 122. Multi-monitor capture policy

Recommended v1:

if multiple docks are visible:

only capture on:

```text
focused monitor
```

Other Dock instances show static app identity placeholder.

This limits total streams.

---

# 123. Active capture owner

Add service property:

```text
activeCaptureScreenName
```

or local arbitration.

Policy:

```text
focused Dock instance gets live stream
```

When focus monitor changes:

old source tears down;
new source starts if visible.

---

# 124. Why single capture owner is preferable

Avoid:

```text
same selected window
captured 2–3 times
```

across monitors.

One live stream is enough for v1.

---

# 125. Pinned Dock performance

With:

```text
captureMode = visible
pinned Dock
```

stream may remain active all session.

This is expected.

Settings should expose:

```text
Capture while:
Visible
Hovered
```

so users can choose lower resource usage.

---

# 126. Capture status diagnostics

Optional Settings info:

```text
Live Preview
Selected app: Figma
Window: Homepage.fig
Capture: Active
```

Useful for debugging.

Do not add permanent status label inside normal Dock unless needed.

---

# 127. Settings UI

Under:

```text
Dock → Content & buttons
```

add:

```text
[ ] Enable Live Preview widget
```

---

# 128. Live Preview settings subsection

Visible when enabled:

```text
Live Preview

Selected app
Figma                     [Change]

Width
4 slots

Capture mode
[ Visible ] [ Hover ]

[ ] Show captured cursor
```

---

# 129. App selector from Settings

Settings can open the same simple picker model but does not need live previews.

Use app list / current running windows.

---

# 130. Context-menu-first setup

User should not need Settings for normal use.

Recommended discoverability:

```text
right-click Dock app
    ↓
Set as Live Preview
```

This is the primary fast workflow.

---

# 131. Widget empty state discoverability

Click empty Live Preview:

```text
opens picker
```

---

# 132. Animation tokens

Add to:

```text
Appearance.qml
```

recommended conceptual tokens:

```text
dockLivePreviewInsert
dockLivePreviewContent
dockLivePreviewSwitch
dockLivePreviewPicker
```

Avoid hard-coded durations scattered across files.

---

# 133. `dockLivePreviewInsert`

For widget main-axis appearance/disappearance.

Suggested feel:

```text
spring / smooth
~320 ms apparent settle
```

---

# 134. `dockLivePreviewContent`

Placeholder ↔ first live frame.

Suggested:

```text
180–220 ms
OutCubic
```

---

# 135. `dockLivePreviewSwitch`

Old app/window → new.

Suggested:

```text
220–300 ms
```

including exit + enter phases.

---

# 136. `dockLivePreviewPicker`

Popup open/close:

```text
180–220 ms
```

---

# 137. Use existing tokens where reasonable

If existing:

```text
elementMoveFast
menuDecel
dockMagnification
```

already matches a specific sub-animation, reuse it.

Do not create four new tokens just for naming consistency if two existing tokens fit.

---

# 138. No continuous decorative animation while hidden

All pulse/loading/hover animations should pause or become irrelevant when:

```text
Dock not revealed
```

Do not run hidden visual loops.

---

# 139. Loading animation

Prefer:

```text
subtle opacity pulse
```

on app icon/placeholder.

No spinner requiring constant rotation unless desired.

---

# 140. No screencopy animation dependency

Animation state must not stall if live capture never produces content.

After failure:

```text
show unavailable state
```

and keep widget functional.

---

# 141. Capture ready timeout

Do not use a recurring timeout.

A one-shot diagnostic timeout may be used:

```text
~1–2 s
```

to switch:

```text
Connecting...
```

to:

```text
Preview unavailable
```

This does not trigger repeated capture attempts.

---

# 142. Widget state machine

Recommended:

```text
empty
appStopped
connecting
live
unavailable
switching
```

---

# 143. State: empty

Condition:

```text
livePreviewAppId == ""
```

UI:

```text
Choose an app
```

---

# 144. State: appStopped

Known app, no Toplevel.

UI:

```text
app icon
app name
Not running
```

Click launches.

---

# 145. State: connecting

Valid Toplevel + capture requested + `hasContent == false`.

---

# 146. State: live

Valid capture content.

---

# 147. State: unavailable

Capture stopped/failed while window exists.

---

# 148. State: switching

Old source exiting / new source waiting.

---

# 149. `paintCursor`

Default:

```text
false
```

Settings toggle changes it live.

No stream restart required unless ScreencopyView implementation requires it.

---

# 150. Screenshot privacy

Do not persist captured frames.

No image files.

No cache written by Live Preview.

---

# 151. Lock screen

Dock already hides when:

```text
GlobalStates.screenLocked
```

Ensure:

```text
captureSource = null
```

as soon as lock state changes.

Do not wait for hide animation during lock.

Privacy takes precedence over smooth exit.

---

# 152. OLED saver/media mode

Dock can be hidden by current global visibility rules.

When Dock PanelWindow becomes unavailable due to:

```text
OLED saver
media mode
```

stop capture immediately.

---

# 153. Sidebar interactions

Current Dock may hide when sidebars open.

Treat resulting:

```text
reveal false
```

with standard teardown delay unless screen lock/private state requires immediate teardown.

---

# 154. App no-screen-share

If selected app is protected:

show unavailable placeholder.

No bypass.

---

# 155. ScreencopyView reuse

Do not duplicate `DockPreviewPopup` component directly.

Extract only a small common helper if there is meaningful duplicated configuration:

```text
constraint sizing
paintCursor
source assignment
```

Do not over-refactor the existing popup during v1.

---

# 156. Potential shared helper

Optional:

```text
widgets/ToplevelScreencopy.qml
```

API:

```qml
ToplevelScreencopy {
    source: ...
    live: ...
    maxSize: ...
    paintCursor: ...
    radius: ...
}
```

Only create if both:

```text
DockPreviewPopup
LivePreviewWidget
```

can use it without increasing complexity.

---

# 157. Avoid risky refactor

The existing DockPreviewPopup works.

Do not make Live Preview implementation depend on rewriting it.

Reuse patterns first.

Refactor later.

---

# 158. Drag ghost

If the Dock drag system renders the actual Live Preview delegate while moving:

stop capture and show compact identity card.

This gives predictable drag performance.

---

# 159. Reorder slot width

Keep Live Preview wrapper width stable during drag.

Do not shrink to one slot just because live capture stops.

Otherwise drag target indexes shift.

---

# 160. Context menu action animation

When a user selects:

```text
Set as Live Preview
```

and widget already exists:

animate old → new source.

If widget disabled:

enable it and run insertion animation.

---

# 161. Selection feedback

No notification toast required.

Visual Dock change is enough.

Optional subtle check icon in context menu.

---

# 162. Widget focus indication

If selected window is currently active:

show subtle:

```text
outline / dot / accent
```

using existing Dock active-app visual language.

Do not introduce a new color system.

---

# 163. Notification badges

Live Preview itself does not need notification badge aggregation.

The source app's normal Dock icon may still exist separately.

Do not hide app icon merely because it is being previewed.

This feature is not Media App Transform.

---

# 164. App icon remains in Dock

Important rule:

Live Preview:

```text
does NOT replace the app icon
```

It is an additional widget.

This avoids surprising taskbar semantics.

---

# 165. Click source app icon

Normal behavior unchanged.

---

# 166. Previewing a non-Dock app

Picker may allow any current Toplevel, even if app is not pinned.

Preferred appId persists.

If app later disappears from normal Dock:

Live Preview still remembers it.

---

# 167. Desktop entry unavailable

If selected Toplevel has no resolvable DesktopEntry:

runtime preview still works.

Persistence may store normalized appId.

If app later closes and cannot be relaunched:

show:

```text
App unavailable
```

rather than trying arbitrary command execution.

---

# 168. Selection persistence safety

Never persist:

```text
command string
shell command
window title as executable
```

Only app identity.

---

# 169. Translation

Add strings to existing translation files following project conventions.

At minimum:

```text
Live Preview
Enable Live Preview widget
Set as Live Preview
Choose an app
Change preview
Follow active window
Preview unavailable
Not running
Connecting preview
Clear preview
Capture while visible
Capture only on hover
Show captured cursor
```

---

# 170. AGENTS documentation

After implementation update:

```text
AGENTS.md
```

Document:

- feature purpose;
- files;
- ScreencopyView lifecycle;
- why `dockRoot.reveal` is used;
- `captureSource = null` resource policy;
- picker model;
- multi-monitor single-capture policy;
- Stack/Islands integration;
- no polling;
- protected-window behavior;
- new Config fields.

Update summary section if required.

---

# 171. Phase 0 — baseline

Before modifying code:

Test current:

```text
DockPreviewPopup ScreencopyView
```

with:

- Firefox;
- Figma/target app;
- terminal;
- XWayland app if available;
- multiple windows.

Confirm current screencopy works reliably on the target NVIDIA/Hyprland setup.

**Exit criterion:** known-good current capture baseline.

---

# 172. Phase 1 — Config/model item

Add:

```text
enableLivePreviewWidget
livePreviewAppId
livePreviewSlots
livePreviewPaintCursor
livePreviewCaptureMode
livePreviewFollowActiveWindow
```

Add:

```text
type: livePreview
```

to DockContent ordering/extents.

Render only placeholder.

**Exit criterion:** widget can be enabled/reordered with no capture code.

---

# 173. Phase 2 — placeholder component

Create:

```text
DockLivePreviewWidget.qml
```

States:

```text
empty
appStopped
```

Implement:

- app icon;
- app name;
- title area;
- click;
- hover controls shell.

**Exit criterion:** UI behaves like a normal Dock widget.

---

# 174. Phase 3 — app/window resolver

Create service/helper.

Implement:

```text
preferred app → candidate app → candidate toplevels
```

Add follow-active behavior.

No screencopy yet.

**Exit criterion:** debug state always resolves expected window.

---

# 175. Phase 4 — single ScreencopyView POC

Add one:

```text
ScreencopyView
```

with selected Toplevel.

Always-active temporarily for development.

**Exit criterion:** selected app is displayed live inside Dock.

This is the critical technical POC.

---

# 176. Phase 5 — capture lifecycle

Implement:

```text
dockRoot.reveal
widget visible
capture mode
selected Toplevel
```

Add hide teardown delay.

**Exit criterion:** stream is absent when Dock is hidden.

---

# 177. Phase 6 — first-frame state

Use:

```text
hasContent
```

Implement:

```text
connecting → live
```

animation.

**Exit criterion:** no blank/black flash during normal reveal.

---

# 178. Phase 7 — app focus behavior

Left click:

```text
activate window
```

App stopped:

```text
execute DesktopEntry
```

**Exit criterion:** widget works as a useful launcher/switcher.

---

# 179. Phase 8 — context-menu selection

Add:

```text
Set as Live Preview
```

to Dock app context menu.

**Exit criterion:** app can be selected with two clicks from Dock.

---

# 180. Phase 9 — picker

Create:

```text
DockLivePreviewPicker.qml
```

Display icons/names/titles.

No live thumbnails.

Add:

```text
clear
follow active
specific window selection
```

**Exit criterion:** user never needs Settings to change preview.

---

# 181. Phase 10 — source-switch animation

Implement:

```text
stable
exiting
waiting
entering
```

state.

**Exit criterion:** no hard source cut.

---

# 182. Phase 11 — widget insertion/removal motion

Add animated main-axis extent and opacity/scale.

**Exit criterion:** enabling/disabling widget does not snap Dock width.

---

# 183. Phase 12 — failure states

Implement:

```text
app stopped
capture unavailable
protected source
capture stopped
```

No retry polling.

---

# 184. Phase 13 — capture hover mode

Add:

```text
visible
hover
```

Settings.

**Exit criterion:** pinned Dock can run without constant screencopy if user chooses hover mode.

---

# 185. Phase 14 — multi-monitor arbitration

Implement:

```text
focused monitor owns live capture
```

Other Dock instances use placeholder/static identity.

**Exit criterion:** max one live Dock preview stream.

---

# 186. Phase 15 — drag/reorder

Stop capture while dragging.

Preserve wrapper width.

**Exit criterion:** Live Preview reorders like other wide widgets.

---

# 187. Phase 16 — Widgets Stack integration

Add Live Preview as stack page.

Start capture during incoming transition.

Stop after outgoing transition.

**Exit criterion:** capture exists only while Live Preview page is active.

---

# 188. Phase 17 — Islands Style integration

Classify as standalone island.

Test:

- island geometry;
- spacing;
- magnification around it.

---

# 189. Phase 18 — vertical Dock

Create compact vertical layout.

Possible:

```text
preview thumbnail
app icon/title minimal
picker button
```

Do not simply rotate horizontal card.

---

# 190. Phase 19 — Settings polish

Add:

```text
enable
selected app
width
capture mode
cursor
```

No complex preview browser.

---

# 191. Phase 20 — documentation

Update:

```text
AGENTS.md
translations
dependency/install docs if necessary
```

No new external dependency should be needed.

---

# 192. Test matrix — lifecycle

- [ ] Dock hidden → no capture source.
- [ ] Dock reveal → capture starts.
- [ ] Dock hides → capture survives exit motion then releases.
- [ ] Dock immediately reopens → teardown canceled.
- [ ] screen lock → capture releases immediately.
- [ ] OLED saver → capture releases.
- [ ] media mode hides Dock → capture releases.
- [ ] widget disabled → capture releases.
- [ ] app closes → capture releases.
- [ ] app reopens → capture restarts.
- [ ] selected window changes → old source exits, new enters.

---

# 193. Test matrix — selected applications

- [ ] native Wayland Qt app.
- [ ] native Wayland GTK app.
- [ ] Firefox.
- [ ] Chromium/Chrome.
- [ ] Electron app.
- [ ] XWayland app.
- [ ] terminal.
- [ ] app with multiple windows.
- [ ] app with no DesktopEntry.
- [ ] protected/no-screen-share app.

---

# 194. Test matrix — picker

- [ ] empty selection.
- [ ] select running app.
- [ ] select pinned/stopped app.
- [ ] select specific window.
- [ ] switch to follow-active.
- [ ] clear preview.
- [ ] close selected window while picker open.
- [ ] app list updates while picker open.

---

# 195. Test matrix — animations

- [ ] widget insert.
- [ ] widget remove.
- [ ] connecting → live.
- [ ] live → stopped app.
- [ ] source A → source B.
- [ ] hover controls.
- [ ] press.
- [ ] picker open/close.
- [ ] Stack incoming/outgoing.
- [ ] Islands movement around preview width.

---

# 196. Test matrix — Dock features

- [ ] magnification enabled.
- [ ] magnification disabled.
- [ ] smart grouping.
- [ ] app groups.
- [ ] files.
- [ ] media widget.
- [ ] weather.
- [ ] sports.
- [ ] phone.
- [ ] Widgets Stack.
- [ ] Islands Style.
- [ ] Media App Transform.
- [ ] auto-hide.
- [ ] pinned Dock.
- [ ] internal drag.
- [ ] external file drop.

---

# 197. Test matrix — capture modes

## Visible

- [ ] auto-hide Dock.
- [ ] pinned Dock.
- [ ] widget visible.
- [ ] Stack page inactive.
- [ ] Stack page active.

## Hover

- [ ] enter widget.
- [ ] leave widget.
- [ ] brief leave/re-enter.
- [ ] picker open while pointer moves.

---

# 198. Test matrix — multiple monitors

- [ ] one monitor.
- [ ] two monitors.
- [ ] same selected app on monitor 1.
- [ ] selected app on monitor 2.
- [ ] isolateMonitors.
- [ ] focused monitor changes.
- [ ] only focused Dock owns stream.
- [ ] non-owner Dock shows placeholder.

---

# 199. Performance validation

Observe with Dock hidden:

```text
no active Live Preview ScreencopyView source
```

Observe with Stack on another page:

```text
no active Live Preview source
```

Observe dragging:

```text
no active source
```

Observe focused visible Dock:

```text
one active source max
```

---

# 200. Performance acceptance

Do not ship if the feature creates:

```text
multiple persistent live streams
```

during normal one-preview usage.

---

# 201. GPU safety

No new:

- blur chain;
- ShaderEffect;
- MultiEffect;
- full-screen FBO;
- dynamic OpacityMask

required.

The capture itself is the only significant rendering cost.

---

# 202. Recommended clipping fallback

Priority:

1. `ClippingRectangle`;
2. square/normal clip if needed;
3. existing OpacityMask only as compatibility fallback.

Avoid blocking feature on perfect rounded clipping.

---

# 203. Potential ScreencopyView limitation

If a window stream produces stale content while occluded:

accept it.

Do not implement app-specific wakeups or forced repaint logic.

The widget remains a compositor preview, not a remote framebuffer.

---

# 204. App minimizing

If minimization causes preview to stop updating:

retain last live/stale frame while stream exists.

If capture stops entirely:

show unavailable state.

---

# 205. Suggested commits

```text
feat(config): add dock live preview settings

feat(dock): add live preview item to dock model

feat(dock): add live preview widget placeholder states

feat(dock): resolve live preview apps and toplevels

feat(dock): render selected window with ScreencopyView

perf(dock): suspend live preview capture while dock is hidden

feat(dock): animate live preview first-frame lifecycle

feat(dock): focus or launch app from live preview

feat(dock): set live preview source from app context menu

feat(dock): add live preview application picker

feat(dock): animate live preview source changes

feat(dock): add hover-only live preview capture mode

fix(dock): arbitrate live preview capture across monitors

fix(dock): suspend screencopy during drag

feat(dock): integrate live preview with widgets stack

feat(dock): integrate live preview with islands style

feat(settings): expose dock live preview controls

docs: document dock live preview architecture
```

---

# 206. Risk analysis

| Area | Risk | Notes |
|---|---|---|
| Screencopy | Low | Existing Dock already uses it |
| App → Toplevel resolution | Low/Medium | Existing Taskbar app model helps |
| Capture lifecycle | Low | Event-driven |
| Picker | Medium | Popup/window lifecycle |
| Source-switch animation | Medium | Must coordinate `hasContent` |
| Multi-window apps | Medium | Active vs locked window semantics |
| Multi-monitor | Medium | Avoid duplicate streams |
| GPU cost | Low/Medium | One stream only while visible |
| NVIDIA stability | Low/Medium | Same path as existing ScreencopyView |
| Stack integration | Low | Capture only on active page |
| Islands integration | Low | Wide standalone widget |
| Vertical Dock | Medium | Needs compact layout |
| Protected windows | Expected limitation | Must fallback cleanly |

---

# 207. Go / No-Go gates

## Gate 1 — basic screencopy

One selected Toplevel must render live reliably inside Dock.

If this fails on target NVIDIA/Hyprland setup, stop before building picker/animations.

---

## Gate 2 — lifecycle

When Dock is hidden:

```text
captureSource == null
```

must be verifiable.

---

## Gate 3 — no blank flashes

Reveal and source changes must use placeholder/`hasContent`.

---

## Gate 4 — picker simplicity

User must be able to select app/window without generating multiple live preview streams.

---

## Gate 5 — one-stream policy

Multi-monitor and Stack scenarios must not accidentally create duplicate persistent streams.

---

## Gate 6 — drag

Reordering Live Preview must not leave stream active or corrupt slot geometry.

---

## Gate 7 — feature integrations

Stack + Islands + magnification must remain stable.

---

# 208. Acceptance criteria

The feature is complete when:

- [ ] New Live Preview Dock toggle exists.
- [ ] Disabled by default.
- [ ] Widget can be reordered.
- [ ] User can select app by right-clicking its Dock icon.
- [ ] User can select/change app from Live Preview picker.
- [ ] User can choose a specific current window.
- [ ] Follow-active-window mode works.
- [ ] App selection persists by app ID.
- [ ] Specific Toplevel selection is runtime-only.
- [ ] Live window is rendered via `ScreencopyView`.
- [ ] Only one live preview stream is active in normal use.
- [ ] Dock hidden releases source.
- [ ] Stack inactive page releases source.
- [ ] Drag releases source.
- [ ] Screen lock releases source immediately.
- [ ] App stopped state is animated.
- [ ] First live frame is animated.
- [ ] Source changes are animated.
- [ ] Widget insertion/removal is animated.
- [ ] Hover controls are animated.
- [ ] Picker is animated.
- [ ] Clicking preview focuses app.
- [ ] Stopped app can be launched from widget.
- [ ] Protected/unavailable preview has graceful fallback.
- [ ] No polling loop is added.
- [ ] No QtMultimedia is added.
- [ ] No external capture process is added.
- [ ] Magnification does not scale Live Preview.
- [ ] Widgets Stack can host Live Preview.
- [ ] Islands Style renders Live Preview as standalone island.
- [ ] Multi-monitor has one active capture owner.
- [ ] Vertical Dock has a usable compact layout.
- [ ] AGENTS.md is updated.

---

# 209. Final architecture target

```text
                       Live Preview
                            │
                    preferred appId
                            │
                            ▼
                     TaskbarApps
                            │
                    resolve windows
                            │
                            ▼
                  selected Toplevel
                            │
                            ▼
                capture lifecycle gate
                            │
      ┌─────────────────────┼─────────────────────┐
      │                     │                     │
 Dock hidden          Stack page hidden        drag active
      │                     │                     │
      └──────────────┬──────┴──────────────┬─────┘
                     │                     │
                 source=null          active + visible
                                           │
                                           ▼
                                    ScreencopyView
                                           │
                                     hasContent
                                           │
                         ┌─────────────────┴──────────────┐
                         │                                │
                       false                             true
                         │                                │
                  placeholder UI                  live preview UI
```

---

# 210. Recommended UX target

## Empty

```text
╭──────────────────────────────────╮
│              +                   │
│          Live Preview            │
│          Choose an app           │
╰──────────────────────────────────╯
```

## App stopped

```text
╭──────────────────────────────────╮
│      [Figma icon]                │
│      Figma                       │
│      Not running            ▶    │
╰──────────────────────────────────╯
```

## Connecting

```text
╭──────────────────────────────────╮
│ ┌──────────────┐                 │
│ │              │  Figma         │
│ │ connecting…  │  Homepage.fig  │
│ │              │                │
│ └──────────────┘                 │
╰──────────────────────────────────╯
```

## Live

```text
╭──────────────────────────────────╮
│ ┌──────────────┐                 │
│ │              │  Figma     ↗ ▾ │
│ │    LIVE      │  Homepage.fig  │
│ │              │                │
│ └──────────────┘                 │
╰──────────────────────────────────╯
```

---

# 211. Final recommendation

Implement the feature in this order:

```text
1. model/config
2. placeholder widget
3. app/Toplevel resolver
4. one ScreencopyView POC
5. capture lifecycle
6. hasContent transitions
7. focus/launch
8. app context-menu action
9. simple picker
10. source-switch animation
11. hover capture mode
12. one-stream multi-monitor arbitration
13. drag
14. Widgets Stack
15. Islands Style
16. vertical Dock
17. Settings/docs
```

The core rule should remain:

```text
Live Preview is a small event-driven window viewer,
not a permanent capture subsystem.
```

The implementation should intentionally prefer:

```text
captureSource = null
```

whenever the preview is not being shown.

That gives the feature the visual impact of the concept while keeping complexity and resource usage under control.
