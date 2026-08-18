# How caelestia grows panels out of the screen border

Research notes for the Cmd+G notepad. Everything below is verified against
caelestia-shell 2.2.0 as shipped at `/etc/xdg/quickshell/caelestia/`, the compiled
plugins under `/usr/lib/qt6/qml/Caelestia/`, and the SDF fragment shader decompressed
out of `lib/libcaelestia-blobs.so`. All `path:line` references are relative to
`/etc/xdg/quickshell/caelestia/` unless stated otherwise.

Written because the notepad is a *separate Quickshell process* and has to reproduce
this by hand — see §9 for what carries across a process boundary and what does not.

---

## 1. The primitive: one SDF field per `BlobGroup`

`Caelestia.Blobs` is a C++/QSG plugin. API, from `caelestia-blobs.qmltypes`:

| type | prototype | properties |
|---|---|---|
| `BlobGroup` | QObject | `smoothing: double`, `color: QColor`, `cornerFill: bool` |
| `BlobShape` | QQuickItem | `group`, `radius`, readonly `deformMatrix`, readonly `rawDeformMatrix` |
| `BlobRect` | BlobShape | `stiffness`, `damping`, `deformScale`, `exclude`, `excludeCorners`, four per-corner radii |
| `BlobInvertedRect` | BlobShape | `borderLeft`, `borderRight`, `borderTop`, `borderBottom` |

Every shape in a group rasterises **the same merged distance field**. The uniform block:

```glsl
float smoothFactor;      // BlobGroup.smoothing
int   rectCount;         // shapes in the group
int   myIndex;           // index of the shape drawing this node
vec4  color;             // BlobGroup.color
int   hasInverted;       // 1 if the group contains a BlobInvertedRect
float invertedRadius;
vec4  invertedOuter;     // centre.xy, halfSize.zw
vec4  invertedInner;
vec4  rectData[80];      // 16 rects * 5 vec4  -> hard cap of 16 shapes per group
```

Per-rect evaluation, in un-deformed space:

```glsl
vec2 extent = sh.xy + vec2(smoothFactor * 1.5);
if (abs(pixel.x-center.x) > extent.x || abs(pixel.y-center.y) > extent.y) { dArr[i]=1e10; continue; }
mat2 invDeform = mat2(invDm.xy, invDm.zw);
vec2 transformedPixel = center + invDeform * (pixel - center);
float d = sdRoundedBox4(transformedPixel, center, rect.zw, radii);
d *= max(props.w, 0.01);
```

`smoothing` is doing two jobs at once: it is the corner-blend radius **and** the
"how close before two shapes fuse" distance (`smoothFactor * 1.5`).

### Shape ↔ shape merge

```glsl
for (int i = 0; i < rectCount; i++) {
    int excludeMask = floatBitsToInt(rectData[i*5+1].x);
    for (int j = i+1; j < rectCount; j++) {
        if ((excludeMask & (1 << j)) != 0) continue;          // <- exclude
        if (max(dArr[i], dArr[j]) >= smoothFactor) continue;
        mergedSdf = min(mergedSdf, smin(dArr[i], dArr[j], smoothFactor));
    }
}
```

Note the loop is **one-directional** — only the lower-indexed shape's mask is read.

### Shape ↔ border merge — the actual mechanism

The border is a frame SDF (outer box minus rounded inner hole). Two terms exist for
it and nothing else:

```glsl
if (hasInverted != 0) {
    float dOuter = sdBox(pixel, invertedOuter.xy, invertedOuter.zw) - 1.0;
    float dInner = sdRoundedBox(pixel, invertedInner.xy, invertedInner.zw, invertedRadius);

    float sinkValue = 0.0;
    for (int i = 0; i < rectCount; i++) {
        float preOff = (smoothFactor * 0.5857864618) * 0.5;      // (2-sqrt2)/2 * k
        float botPen = clamp(((ctr.y - sinkSh.y) - innerBot) - preOff, 0.0, outerBot - innerBot);
        // ... topPen / leftPen / rightPen likewise
        float hLat = max(abs(pixel.x - ctr.x) - sinkSh.x, 0.0);
        float s = smoothFactor * 2.0;
        float sink = max(..., botPen * smoothstep(s, 0.0, hLat) * botZone, ...);
        sinkValue = max(sinkValue, sink);
    }
    dInner -= sinkValue;                                        // hole eaten away locally

    float minThick = min(min(innerTop-outerTop, outerBot-innerBot),
                         min(innerLeft-outerLeft, outerRight-innerRight));
    float kFrame  = clamp(min(smoothFactor, minThick - 1.0), 1.0, smoothFactor);
    float dFrame  = smaxSharpA(dOuter, -dInner, kFrame);
    mergedSdf = smin(mergedSdf, dFrame, smoothFactor);          // panel fuses to border
    if (dFrame < minDist) owner = -1;
}
```

and the reciprocal term, inside the per-rect loop:

```glsl
float yProx = 1.0 - min(smoothstep(0.0, smoothFactor, distY0), smoothstep(0.0, smoothFactor, distY1));
float xProx = 1.0 - min(smoothstep(0.0, smoothFactor, distX0), smoothstep(0.0, smoothFactor, distX1));
float scale = 1.0 + ((xProx * xWeight) + (yProx * yWeight)) * 3.0;   // boost = 3
d *= scale;
```

**These two are the whole illusion.** A blob near the frame locally eats the frame's
inner edge outward by exactly how far it penetrates, and simultaneously has its own
field steepened up to 4×. The first makes the fillet; the second keeps it tight
instead of ballooning as the panel arrives and decelerates.

Neither term fires against a plain `BlobRect`. Standing a rect in for the border does
not approximate this — it produces a fillet that blooms and snaps.

### Single ownership, and why `layer.enabled` is mandatory

```glsl
if (owner != myIndex && mergedSdf > smoothFactor) discard;
float fw = fwidth(mergedSdf);
float alpha = 1.0 - smoothstep(-fw, fw, mergedSdf);
fragColor = vec4(color.xyz * alpha, alpha) * qt_Opacity;
```

Each fragment is emitted by the shape that owns it (`owner = -1` for the frame) — but
only **outside** the blend zone. Inside a fillet, every overlapping shape draws. So at
`opacity < 1` the seam would composite twice (`1-(1-a)²` = 0.98 at a = 0.85) and read
as a darker band. Flattening the whole group into one texture first is what makes a
merged blob composite at one uniform alpha. See §6.

---

## 2. Every use of the blob types

Five files. `BlobShape` is never instantiated directly.

```
modules/drawers/ContentWindow.qml          <- the screen group
modules/nexus/Nexus.qml                    <- a second, independent group
modules/nexus/common/BlobPopup.qml         <- "popup grows out of its button"
modules/dashboard/media/LyricsInfo.qml     <- same idiom, per-instance
modules/nexus/common/PopupRow.qml          <- hosts a BlobPopup, no direct Blob types
```

### 2a. The screen group — `modules/drawers/ContentWindow.qml`

```qml
// :159-164
BlobGroup {
    id: blobGroup
    color: root.surfaceColour
    smoothing: root.contentItem.Config.border.smoothing
}
```

`cornerFill` left at the C++ default (true). `color` is `Colours.tPalette.m3surface`
(`:45`), cross-faded by `CAnim` at `:84-86`.

The border:

```qml
// :166-175
BlobInvertedRect {
    anchors.fill: parent
    anchors.margins: -50 // Make border thicker to smooth out bulge from closed drawers
    group: blobGroup
    radius: root.borderRounding
    borderLeft: bar.implicitWidth - anchors.margins - root.sdfBorderOffset
    borderRight: root.borderThickness - anchors.margins - root.sdfBorderOffset
    borderTop: root.borderThickness - anchors.margins - root.sdfBorderOffset
    borderBottom: root.borderThickness - anchors.margins - root.sdfBorderOffset
}
```

The `-50` is load-bearing, not cosmetic. `kFrame = clamp(min(smoothFactor, minThick-1),
1, smoothFactor)` reads the **whole** frame thickness. At a realistic
`Config.border.thickness` (~10) `minThick` would clamp `kFrame` down and a closed panel
resting just outside the hole would still visibly bulge the inner edge. Inflating the
frame 50px outward on all four sides — and compensating every `border*` by
`- anchors.margins` — keeps the *hole* identical while making the frame arbitrarily
thick, so `kFrame == smoothFactor` always.

The shared panel component — the single definition of "a panel is a blob in border
coordinates":

```qml
// :337-348
component PanelBg: BlobRect {
    required property Item panel
    property real deformAmount: 0.15

    group: blobGroup
    x: panel.x + bar.implicitWidth
    y: panel.y + root.borderThickness
    implicitWidth: panel.width
    implicitHeight: panel.height
    radius: Tokens.rounding.extraLarge
    deformScale: (deformAmount * Config.appearance.deformScale) / 10000
}
```

The eight instances, and why each number differs:

| id | line | panel | `deformAmount` | reason |
|---|---|---|---|---|
| `dashBg` | 177 | dashboard | 0.1 | large slab, low wobble |
| `launcherBg` | 184 | launcher | 0.1 | same |
| `sessionBg` | 191 | sessionWrapper | 0.2 | small and fast, springier |
| `sidebarBg` | 200 | sidebar | 0.03 | full-height column; more visibly warps a screen-height edge |
| `osdBg` | 210 | osdWrapper | 0.25 | smallest and fastest, most wobble |
| `notifsBg` | 219 | notifications | 0.15 (default) | |
| `utilsBg` | 225 | utilities | `sidebar.visible ? 0.1 : 0.15` | damped while fused to the sidebar so the two don't wobble against each other |
| `popoutBg` | 234 | popoutsWrapper | `isDetached ? 0.05 : hasCurrent ? 0.15 : 0.1` | 0.05 when floating free — no border to peel from |

Three override `x`/`implicitWidth` because their `panel` is a *clip wrapper* whose
width is already scaled by `(1 - offsetScale)`; the blob must track the un-clipped
child instead:

```qml
// :196-197 session   :215-216 osd   :242-243 popouts
x: panels.sessionWrapper.x + panels.session.x + bar.implicitWidth
implicitWidth: panels.session.width
```

`popoutBg` additionally runs 20% wider than its content, shifted left by that amount so
its left edge is buried inside the bar:

```qml
// :237-238, :245-247
// Extra width to prevent vertical movement deformation partially detaching panel from bar
property real extraWidth: panels.popouts.isDetached ? 0 : 0.2
Behavior on extraWidth { Anim {} }
```

When the popout slides vertically to follow the hovered bar module, the horizontal
squash from `deformScale` would otherwise momentarily pull its left edge out of the
border and snap the neck.

`sidebarBg` feeds its own deform back into its size:

```qml
// :205
implicitHeight: panel.height * (1 / rawDeformMatrix.m22) + 2
```

Dividing by the raw vertical scale keeps the *rendered* height equal to the panel
height, so a screen-height column stays welded to both the top and bottom border while
it wobbles. The `+ 2` is slop against SDF join imprecision.

`stiffness` and `damping` are **never set anywhere in the tree** — every `BlobRect`
runs the C++ defaults. `excludeCorners` is never used in QML either.

### 2b. `modules/nexus/Nexus.qml` — the idiom applied recursively

```qml
// :34-51
BlobGroup { id: blobGroup; smoothing: root.Tokens.rounding.medium; color: root.blobColour }

BlobInvertedRect {
    anchors.fill: parent
    group: blobGroup
    opacity: root.blobColour.a
    radius: Tokens.rounding.large
    borderLeft: navPane.width + navPane.anchors.margins * 2
    borderRight: Tokens.padding.medium
    borderTop: Tokens.padding.medium
    borderBottom: Tokens.padding.medium
}
```

The same border-as-inverted-rect trick *inside* a panel: the nav pane is the "bar", the
page area is the "hole". Its one `BlobRect` (`:53-66`) sets
`anchors.margins: nState.isWindow ? 0 : Tokens.padding.extraSmall` — flush with the
corner so it fuses into the frame when it is a window, padded inward so it reads as a
separate pill when it is a popout.

### 2c. `modules/nexus/common/BlobPopup.qml` — "grows out of a button"

```qml
// :30-40
BlobGroup {
    color: Colours.palette.m3surfaceContainerHighest
    smoothing: root.Tokens.rounding.medium
    cornerFill: false
    Behavior on color { CAnim {} }
}
```

`cornerFill: false` appears exactly twice (here and `LyricsInfo.qml:23`). Both groups
have no `BlobInvertedRect`; corner fill is a frame-corner behaviour, and disabling it
keeps the button/popout pair reading as two liquid pills rather than a filled wedge.

```qml
// :61-99  (the growing body)
BlobRect {
    id: rect
    radius: Tokens.rounding.large
    deformScale: 0.00001                    // effectively zero deform

    states: State { name: "open"; when: root.open
        PropertyChanges {
            rect.anchors.rightMargin: root.width - root.Tokens.spacing.small
            rect.anchors.topMargin: -root.topMovement
            rect.implicitWidth: root.content.implicitWidth + root.padding * 2
            rect.implicitHeight: root.content.implicitHeight + root.padding * 2
        }
    }
    transitions: Transition {
        Anim { properties: "rightMargin,implicitWidth" }
        Anim { properties: "topMargin,implicitHeight"; easing: root.Tokens.anim.expressiveFastSpatial }
        Anim { property: "animDriver"; type: Anim.DefaultEffects }
    }
}
```

Two things worth stealing. The body must **not** wobble (`deformScale: 0.00001`) because
what sells the growth is the `smin` neck between it and the button blob, and springy
overshoot on the growing rect tears that neck — the button keeps its default deform, the
body does not. And the easing is deliberately split: width on the default spatial curve,
height on `expressiveFastSpatial`, so the blob visibly *stretches upward then unfurls
sideways*.

`LyricsInfo.qml:18-89` is the same construction with `Tokens.rounding.medium` and extra
`Behavior on implicitWidth/implicitHeight` for content-driven resizes outside the state
change.

---

## 3. `exclude` — when caelestia deliberately *prevents* a merge

Two sites, both in `ContentWindow.qml`, both the sidebar↔utilities seam:

```qml
// :200-208
PanelBg {
    id: sidebarBg
    panel: panels.sidebar
    deformAmount: 0.03
    implicitHeight: panel.height * (1 / rawDeformMatrix.m22) + 2
    exclude: panels.sidebar.offsetScale > 0.08 ? [] : [utilsBg]
    bottomLeftRadius: Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius
}
// :225-232
PanelBg {
    id: utilsBg
    panel: panels.utilities
    deformAmount: panels.sidebar.visible ? 0.1 : 0.15
    exclude: panels.sidebar.offsetScale > 0.08 ? [] : [sidebarBg]
    topLeftRadius: Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius
}
```

**Read the polarity carefully — it is inverted from how it looks.** `offsetScale === 0`
is fully *open*; `1` is fully closed. So `> 0.08` (still travelling) → `exclude: []` →
merging **allowed**; `<= 0.08` (arrived) → `exclude: [theOther]` → merging **forbidden**.

The problem being solved: `Panels.qml:145-154` stacks the sidebar directly on utilities
(`sidebar.anchors.bottom: utilities.top`) and `utilities/Wrapper.qml:36` makes utilities
adopt the sidebar's exact width while it is open. Two flush, same-width rectangles
sharing an edge. Left to `smin`, `smoothing` bleeds a fat fillet across that edge and
the intended seam — utilities is meant to read as a distinct dock beneath the sidebar —
dissolves into one featureless slab. But during the *transition* they must merge, or the
sidebar appears to slide over a separate object rather than the pair growing as one
mass. Hence: fuse during travel, split on arrival.

The corner radii do the reciprocal job on a deliberately **slower** schedule (`/0.3` vs
the `0.08` exclusion gate): both facing corners are already ~73% squared off by the time
merging is cut, so the seam lands as a clean butt joint rather than two rounded corners
with a notch between them.

Setting `exclude` symmetrically on both is defensive — the shader only consults the
lower-indexed shape's mask, and in declaration order `sidebarBg` is index 3 while
`utilsBg` is 6, so only `sidebarBg.exclude` actually fires.

---

## 4. The border geometry contract

### The scalars

```qml
// :38-43
property real fsTransitionProg: hasFullscreen ? 1 : 0
readonly property real sdfBorderOffset: 2 * fsTransitionProg // SDFs joins are not exact, so offset by 2px to ensure nothing shows
readonly property real borderThickness: contentItem.Config.border.thickness * (1 - fsTransitionProg)
readonly property real borderRounding: contentItem.Config.border.rounding * (1 - fsTransitionProg)
readonly property real shadowOpacity: 0.7 * (1 - fsTransitionProg)
readonly property real borderLayoutThickness: hasFullscreen ? 0 : contentItem.Config.border.thickness
```

Every geometric quantity is one lerp on `fsTransitionProg`, itself a single
`Behavior on fsTransitionProg { Anim {} }` (`:80-82`). `sdfBorderOffset` runs the
opposite way — 0 normally, 2px at fullscreen — so the frame ends up 2px *thinner* than
zero and no hairline of surface colour survives at the screen edge.

`borderLayoutThickness` (hard 0/thickness, unanimated) goes to `Interactions`; the
animated `borderThickness` goes to `Panels`. **Hit-testing snaps, geometry lerps.**

`Config.appearance.deformScale` is a single global multiplier over every panel's wobble
(`:347`).

### The coordinate rule

**Panel-local → window coordinates is `+bar.implicitWidth` horizontally,
`+borderThickness` vertically**, because `Panels` is inset by exactly that:

```qml
// Panels.qml:37-39
anchors.fill: parent
anchors.margins: borderThickness
anchors.leftMargin: bar.implicitWidth
```

Re-applied in ~25 places: `ContentWindow.qml:91-92, 98-99, 171-174, 196, 215, 242,
342-343`; `Regions.qml:18-21, 78-79`; `Interactions.qml:27, 32, 37, 41, 46, 51, 57, 134,
138-139, 183-184, 241`; `Exclusions.qml:17, 35`; `Background.qml:67`;
`Visualiser.qml:62-63`.

A second, subtler half of the illusion shows up in five panels:

```qml
// notifications/Content.qml:22 — and sibling lines in session, osd, sidebar, utilities
clampedPadding: CUtils.clamp(padding - Config.border.thickness, 0, padding)
```

On the edge a panel touches the border, its inner padding is reduced by the border
thickness. **The border counts as padding**, so the visual gap between content and the
outside world stays constant no matter how thick the frame is.

### `Regions.qml` — input masking

```qml
// :15-22
x: bar.clampedWidth + win.dragMaskPadding
y: clampedThickness + win.dragMaskPadding
width:  win.width  - bar.clampedWidth - clampedThickness - win.dragMaskPadding * 2
height: win.height - clampedThickness * 2 - win.dragMaskPadding * 2
intersection: Intersection.Xor
```

```qml
// :75-83
component R: Region {
    required property Item panel
    x: panel.x + root.bar.implicitWidth
    y: panel.y + root.borderThickness
    width: panel.width
    height: panel.height
    intersection: Intersection.Subtract
}
```

The root region is the desktop interior; each `R` subtracts a panel's rect; the whole
thing is XOR'd against the window. Result: the shell receives input on
*border ∪ bar ∪ drag gutter ∪ every open panel*, and clicks on bare desktop fall
through to Hyprland clients.

**The mask does not follow the blob shape** — it is an axis-aligned rectangle union.
What it *does* do is compensate for the reveal animation:

```qml
// :24-34
R { panel: root.panels.dashboard; y: 0
    height: panel.height * (1 - root.panels.dashboard.offsetScale) + root.borderThickness }
R { panel: root.panels.launcher;  y: root.win.height - height
    height: panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness }
```

Each edge-anchored panel's region is pinned to the screen edge and sized to the
*visible fraction* plus `borderThickness`. Because panels travel by negative anchor
margin, a naive `R` would leave an unmasked hairline between the panel's leading edge
and the border mid-animation, and the cursor would drop through to the client
underneath while the drawer opened.

Right-edge panels additionally **stack** (`:36-56`): OSD ⊃ session ⊃ sidebar, because
each pushes the next leftward and every outer region must span the pushed-out distance.

`Exclusions.qml` is deliberately dumb — four 1×1 masked-out windows whose only job is to
reserve compositor exclusive zones (`:32-39`). The drawers window itself is
`ExclusionMode.Ignore` so it can be fullscreen and still leave a hole for clients.

---

## 5. The reveal idiom

**`offsetScale ∈ [0,1]`, 0 = open, 1 = closed. Every panel is `shouldBeActive ? 0 : 1`
with `Behavior on offsetScale { Anim {} }`.** A bare `Anim {}` is `Anim.DefaultSpatial`
→ `expressiveDefaultSpatial`.

**There is no separate open/close curve for panels.** Same `Behavior`, same curve both
directions, everywhere.

| panel | file | mechanism |
|---|---|---|
| dashboard | `dashboard/Wrapper.qml:29-39` | translate (anchor margin) + fade |
| launcher | `launcher/Wrapper.qml:25-44` | translate + fade + binding break |
| session | `session/Wrapper.qml:15-26` | translate + fade, clipped by parent |
| sidebar | `sidebar/Wrapper.qml:15-24` | translate + fade |
| osd | `osd/Wrapper.qml:19-49` | translate + fade, clipped by parent |
| utilities | `utilities/Wrapper.qml:30-71` | translate + fade + implicit-width lerp |
| popouts (outer) | `bar/popouts/ClipWrapper.qml:15-53` | **clip** + inner translate |
| popouts (inner) | `bar/popouts/Wrapper.qml:153-167` | implicit size |
| notifications | `notifications/Wrapper.qml` | **no offsetScale** — pure implicit height |

The canonical form:

```qml
// dashboard/Wrapper.qml:29-39
property real offsetScale: shouldBeActive ? 0 : 1

visible: offsetScale < 1
anchors.topMargin: (-implicitHeight - 5) * offsetScale
opacity: 1 - offsetScale

Behavior on offsetScale { Anim {} }
```

**The `-5` is not a rounding fudge.** Panels rest *past* the border, never flush with
it — a 0px gap still bulges the frame while closed, for the same
`SDFs joins are not exact` reason as `sdfBorderOffset`. Session and OSD extend it to a
sidebar-aware `-5 - sidebarOffset` (14 and 12 respectively) because they must travel
further to clear an open sidebar.

The launcher breaks its own binding so a closing panel does not resize while it slides:

```qml
// launcher/Wrapper.qml:27-32
onShouldBeActiveChanged: {
    if (shouldBeActive) implicitHeight = Qt.binding(() => content.implicitHeight);
    else                implicitHeight = implicitHeight; // Break binding during close anim
}
```

### Clip wrappers — "one panel pushes another"

`Panels.qml:41-62` (osd) and `:77-97` (session) wrap the panel in a plain `Item` whose
implicit size **is the visible fraction**, with `clip: true` enabled only while a
neighbour is visible:

```qml
anchors.rightMargin: sessionWrapper.anchors.rightMargin + session.width * (1 - session.offsetScale)
clip: sidebar.visible || session.visible
implicitWidth: osd.implicitWidth * (1 - osd.offsetScale)
```

Sidebar width pushes `sessionWrapper` left; session width pushes `osdWrapper` left.
This is why `sessionBg`/`osdBg` add `wrapper.x + child.x` — the blob follows the inner
item, not the shrinking clip box.

### The two genuinely asymmetric curves

Utilities attaching to the sidebar (`utilities/Wrapper.qml:47-66`) — `standardAccel`
in, `standardDecel` out, both at half duration. Attach accelerates *into* the lock-up;
detach decelerates *out* of it.

The bar (`bar/BarWrapper.qml:39-72`) — open on `expressiveDefaultSpatial`, close on
`Anim.Emphasized`.

### Popouts clip rather than translate

```qml
// bar/popouts/ClipWrapper.qml:15-53
property real offsetScale: x > 0 || content.hasCurrent ? 0 : 1
clip: true
implicitWidth: content.implicitWidth * (1 - offsetScale)

Behavior on y {
    enabled: root.offsetScale < 1        // a closed popout must TELEPORT to the next
    Anim { duration: content.animLength; easing: content.animCurve }
}
```

Both at once: the clip box shrinks to zero *and* the content translates
`(-implicitWidth - 5) * offsetScale` inside it (`:55-64`). Detaching swaps the curve to
`expressiveSlowSpatial` via `setAnims()` (`Wrapper.qml:37-57`), bracketed around the
state change so only that transition picks it up.

---

## 6. Shadows and opacity

```qml
// ContentWindow.qml:149-157
Item {
    anchors.fill: parent
    opacity: root.surfaceColour.a
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        blurMax: 15
        shadowColor: Qt.alpha(Colours.palette.m3shadow, Math.max(0, root.shadowOpacity))
    }
    // BlobGroup, BlobInvertedRect, 8x PanelBg
}
```

Three things happen, in order: the frame and all eight panel blobs render to one FBO;
`MultiEffect` shadows the **silhouette of that FBO's alpha**; then a single `opacity` is
applied to the flattened result.

Step three is why the shader's ownership `discard` exists (§1). Flattening plus
one-writer-per-pixel is the *entire* reason transparency works on a merged shape.

Two consequences worth knowing:

- **The frame's inner edge does cast a shadow inward, into the hole.** The layer's alpha
  includes the inverted rect, which is opaque everywhere except the hole; the hole
  boundary is an alpha edge like any other and blurs inward ~15px. That is what makes
  the desktop look recessed behind the frame.
- **A merged panel has no internal edge, so no shadow is drawn at the seam.** Merged
  blobs are shadowed only around the outside of the combined silhouette. That is the
  visual proof of the merge — and, for anything outside this process, an unreachable
  effect (§9).

`surfaceColour` is cross-faded, not assigned:

```qml
// :45, :84-86
property color surfaceColour: Colours.tPalette.m3surface
Behavior on surfaceColour { CAnim {} }        // expressiveSlowEffects
```

Elsewhere in the tree, `Elevation.qml` (a `RectangularShadow`, `dp: [0,1,3,6,8,12][level]`)
covers ordinary Material elevation, and `layer.enabled: opacity < 1` appears at
`components/controls/Menu.qml:48-49`, `modules/nexus/Pages.qml:43` and
`modules/dashboard/dash/User.qml:98` — the lazy version of the same flatten-before-fade
trick, paying for the FBO only while actually fading. `ContentWindow` cannot do that
because it also needs the layer for the shadow.

---

## 7. Transparency and blur wiring

Namespaces come from `components/containers/StyledWindow.qml:10`:
`` WlrLayershell.namespace: `caelestia-${name}` ``.

```qml
// services/Colours.qml:85-95
function reloadHyprRules(): void {
    let rule, trEnabled;
    if (Hypr.usingLua) {
        rule = `eval hl.layer_rule({ match = { namespace = "caelestia-drawers" }, %1 = %2 })`;
        trEnabled = transparency.enabled;
    } else {
        rule = "keyword layerrule %1 %2, match:namespace caelestia-drawers";
        trEnabled = transparency.enabled ? 1 : 0;
    }
    Hypr.extras.batchMessage([rule.arg("blur").arg(trEnabled),
                              rule.arg("ignore_alpha").arg(Math.max(0, transparency.base - 0.03))]);
}
```

**Two rules, one namespace.** `xray` and `no_anim` are never emitted anywhere in the
tree. (`no_anim` matters for the notepad, which *is* mapped and unmapped per toggle —
caelestia's drawers window is mapped once at startup and never unmapped, so it never
hits Hyprland's `layersIn` animation.)

`ignore_alpha` at `base - 0.03` tells Hyprland to skip blurring anything below that
threshold, so the near-zero-alpha region inside the border hole is not blurred while the
blob mass (at exactly `base`) is. The 0.03 margin stops floating-point equality making
the surfaces flicker in and out of blur.

The scheduling is asymmetric on purpose:

```qml
// :149-167
onEnabledChanged: { if (enabled) root.requestReloadHyprRules(); else cAnimCompleteTimer.start(); }
onBaseChanged: {
    if (root.lastBaseTransparency > base) root.requestReloadHyprRules();
    else                                  cAnimCompleteTimer.start();
    root.lastBaseTransparency = base;
}
```

Getting **more** transparent applies immediately behind a 30 ms cooldown
(`:97-104`, `:129-140`). Getting **less** transparent waits
`Tokens.anim.durations.expressiveSlowEffects` — the full `CAnim` duration used by
`Behavior on surfaceColour`. Otherwise `ignore_alpha` rises above the surface's current
animated alpha mid-fade and the blur pops off before the colour finishes.

The colour side (`:37-54`): `layer === 0` → pure `Qt.alpha(c, transparency.base)`, used
for base surfaces (`m3surface`, `m3background`, …). Everything else goes through
`alterColour` at `transparency.layers` alpha with a luminance boost proportional to
`(1 - transparency.base)` **and the wallpaper's brightness** (from an `ImageAnalyser` on
the current wallpaper) — the more transparent the base and the brighter the wallpaper,
the further layered colours are pushed from mid-grey to stay legible.

---

## 8. Everything else that "animates from the border"

**The bar *is* the left border.** `BarWrapper.implicitWidth` rests at
`Config.border.thickness` and animates to `contentWidth`; `BlobInvertedRect.borderLeft`
is `bar.implicitWidth`; `PanelBg.x` is `panel.x + bar.implicitWidth`;
`Panels.anchors.leftMargin` is `bar.implicitWidth`. There is no bar object distinct from
the border — showing the bar just thickens one edge of the frame, and the whole blob
group re-solves around it in the same frame.

**Fullscreen collapse.** One `fsTransitionProg` simultaneously retracts thickness and
rounding to 0, engages the 2px overshoot, fades the shadow, zeroes the bar width, swaps
the input mask, promotes the layer, and force-closes every panel. The border literally
retracts into the screen edge and the entire blob mass collapses with it, because
everything is anchored to it.

**Cross-window geometry coupling** without singletons: `ShellState.ComponentRef`
(`ContentWindow.qml:313-335`) publishes `rootWindow`, `interactionWrapper`, `bar`,
`panels` per screen. `Visualiser.qml:63` reads the bar's exclusive zone out of a
*different window* and animates its own left margin on the same curve, so the audio bars
slide in lockstep with the bar.

**`modules/utilities/RecordingDeleteModal.qml:50-136`** is worth knowing about: a
hand-authored `Shape` (`Shape.CurveRenderer`) that reproduces the concave border fillet
in plain QML — two `ShapePath`s of `PathCubic` with control points at
`smoothing * 0.93 / -smoothing * 0.07`, filled with a gradient. It exists because a
*scrim* cannot join the blob group's colour, so its corners have to be drawn by hand to
match. `Config.border.smoothing` appears 14 times in that one file.

**`modules/nexus/common/ConnectedRect.qml`** is the non-SDF fallback for the same visual
language — stacked rows read as one continuous column purely by squaring interior
corners, the same trick as `sidebarBg.bottomLeftRadius` in §3, done with plain rects
where a blob group would be overkill.

---

## 9. What the notepad can and cannot inherit

The notepad is a separate Quickshell process (`qs -p .../custom/notepad`), on its own
Wayland layer surface, above `caelestia-drawers`.

### Carries across

- **`Caelestia.Config`** — `Tokens` and `Config` are compiled plugins installed to
  `/usr/lib/qt6/qml/`, importable from any config. The notepad reads caelestia's real
  rounding, spacing, fonts, animation curves, border thickness/rounding/smoothing and
  transparency settings, not a copy of them. Both are *per-screen attached*: a plain
  QObject like `BlobGroup` does not inherit the screen the window sets on
  `contentItem`, so it must be set explicitly.
- **`Caelestia.Blobs`** — the notepad builds its own `BlobGroup` containing a
  `BlobInvertedRect` replica of the border plus one `BlobRect` panel. Since the frame is
  real, both border-specific shader terms (§1) fire, and the fillet where the panel
  meets the bottom border is produced by the same code that produces caelestia's.
- **The colour scheme** — `~/.local/state/caelestia/scheme.json` is rewritten by matugen
  through the caelestia CLI on every wallpaper change. A `FileView { watchChanges: true }`
  is the whole retheme mechanism; there is nothing to restart and no IPC involved.
- **Every convention in §5–§7** — `offsetScale`, the `-5` rest offset, one bare `Anim {}`
  in both directions, `layer.enabled` before `opacity`, `Behavior on surfaceColour { CAnim {} }`,
  the `blur` + `ignore_alpha` pair, and the asymmetric reload scheduling.

### Does not carry across

- **Merging with caelestia's own panels.** `BlobGroup` is a per-process C++ object with a
  hard 16-shape cap. Opening the launcher and the notepad together gives two independent
  shapes that cannot see each other's distance field. Only an in-process module could
  fuse with the bar or the launcher the way caelestia's own popouts do.
- **`ImageAnalyser` wallpaper luminance**, so `alterColour` runs without its
  `wallLuminance` term. Consequence: layered surfaces are tuned slightly darker over very
  bright wallpapers than caelestia's own.
- **The bar's live width.** It is a layout value inside caelestia's process. The notepad
  carries a measured constant (`barWidth: 60` logical, = 95 physical at scale 1.6), which
  is correct while `bar.persistent` holds. Re-measure if that changes:
  `grim /tmp/s.png` then find the x where the bar's surface colour gives way to content.

### The bottom edge — measured, not assumed

The panel must rest flush with the hole (`(-implicitHeight - 5) * offsetScale` inside an
item inset by `borderThickness`), **not** `borderThickness` below it. Pinned below, the
notepad renders nothing across a ~20px band above the border and whatever is behind
shows through it — a hard dark bar.

Once flush, the edge is clean. Measured on one fixed wallpaper, three captures taken
back to back (screen closed / notepad open / caelestia launcher open), row means over
x=1000–1700, red channel, physical pixels; the border begins at y=1584:

| y | wallpaper | notepad | launcher |
|---|---|---|---|
| 1554 | 80.5 | 21.0 | 31.7 |
| 1563 | 248.3 | 22.0 | 33.4 |
| 1572 | 177.8 | 21.3 | 34.9 |
| 1575 | 173.9 | 20.7 | **27.7** |
| 1581 | 151.3 | 18.9 | 28.8 |

The notepad varies by 3 units across the last 30px. Caelestia's own launcher steps
**−7.2** at y=1575. The notepad's bottom edge is smoother than caelestia's.

Two traps worth recording, because both produced convincing false positives:

- **The wallpaper cycles.** Comparing an "open" capture against a "closed" capture taken
  minutes earlier attributes a wallpaper feature — the 80 → 248 spike at y=1563 above —
  to the panel. Always capture the pair back to back.
- **A boosted crop lies.** `(v/50)**0.5` maps 15 → 139 and 30 → 197, so a real 2:1 ratio
  and a meaningless one look identical. Read numbers; use crops only to locate.

To settle whether a suspected gap is geometry or compositing, force the blob layer
`opacity: 1` for one capture. Opaque, this panel reads a uniform `[5,3,2]` from mid-panel
to y=1583 with no gap at all, which rules out geometry in a single shot.

Caelestia's border does cast its `MultiEffect` shadow inward into the hole (§6), and the
notepad is a layer above it, so in principle some of that shadow is visible through the
panel's 0.85 alpha. It does not survive measurement above the noise, and it applies
equally to caelestia's own panels, so it cannot explain a difference between them. Do not
invoke it as an excuse for a visible band — measure first.

For the record, since it is easy to reach for: Hyprland 0.56.2 has no `xray` *layerrule*
(only `decoration:blur:xray` and `misc:session_lock_xray` exist in the binary), and a
second translucent pass over the border composites to `1-(1-a)²` — 0.98 at a=0.85 — so
neither is available as a remedy.

### Coexisting with caelestia's panels

A fullscreen layer surface one level above `caelestia-drawers` will swallow every click
meant for the shell underneath. The notepad therefore masks its input to the panel rect
only (`mask: panelRegion`), the same way caelestia masks to its chrome
(`ContentWindow.qml:73`). Click-outside-to-dismiss is incompatible with this — it *is*
the act of swallowing those clicks — so dismissal is Escape and SUPER+G.

Keyboard focus is a genuine trade-off with no correct answer:

- `Exclusive` (current) — the notepad receives keys the moment it opens, without a click.
  While it is open, keys go to it rather than to a caelestia panel opened underneath.
- `OnDemand` — caelestia's panels stay typeable, but the notepad may need a click before
  it accepts input. Caelestia gets away with `OnDemand` because its panels pair it with a
  `HyprlandFocusGrab`, and a grab would take the pointer back and undo the mask above.

`Exclusive` is chosen because typing is this panel's primary function. It is one word to
change in `NotepadWindow.qml` if that ranking is ever wrong.
