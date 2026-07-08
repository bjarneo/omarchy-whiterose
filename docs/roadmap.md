# Whiterose roadmap and architecture

The goal: a full replacement UI for the Omarchy shell that feels native,
reads expensive, stays minimal, and can be themed by anyone. This document
is the plan, the decisions behind it, and what is left to build.

## Design principles

1. Native first. Every widget extends the shell's own primitives
   (`BarWidget`, `WidgetButton`, `Panel`, `KeyboardPanel`, `BorderSurface`).
   Hover, tooltips, popout coordination, drag-reorder, and vertical bars
   work exactly like stock widgets because they are the stock plumbing.
2. Tokens only. No hardcoded colors, sizes, or fonts. Colors come from
   `Color.*` (per-surface roles from the theme's `shell.toml`), spacing
   from `Style.spacing.*` / `Style.space()`, type from `Style.font.*`.
   The font is the system monospace alias; `omarchy font set` changes it.
3. Quiet motion. Animations are 120-180 ms, `Easing.OutCubic`, matching
   the shell's own constants. One slow exception: the clock separator
   breathes at 900 ms per half-cycle. Nothing bounces, nothing slides far.
4. Accessible. Contrast comes from the theme's fg/bg pair, state is never
   color-only (glyphs change shape, labels change text), everything is
   reachable by keyboard, destructive actions need a second Enter.
5. One accent. The hacker note is restraint: prompt glyphs, hairlines,
   uppercase micro-labels with letter spacing, a breathing colon. No neon,
   no scanlines, no green-on-black cliche.

## Architecture

```text
whiterose-omarchy/
|- plugins/               one directory per plugin (= one manifest each)
|  |- whiterose.menu/     kinds: menu + bar-widget (Menu.qml, BarWidget.qml, Data.js)
|  |- whiterose.<widget>/ kinds: bar-widget (Widget.qml)
|- theme/whiterose/       colors.toml + shell.<section>.toml + backgrounds/
|- extensions/            optional rows for the stock menu
|- install.sh             symlink plugins, copy theme, rescan, enable
```

Key platform facts (from the shell source, `services/PluginRegistry.qml`):

- One plugin directory = one manifest = at most one bar widget. Distinct
  widgets need distinct plugin directories. `allowMultiple: true` permits
  several instances of the same widget.
- Bar widgets are referenced in `shell.json` `bar.layout.<section>` by
  their manifest id. Inline keys on the entry are the widget's `settings`.
- Menus/overlays get `open(payloadJson)` / `close()` called by the host.
  `keepLoaded: true` keeps the instance alive between summons.
- Widgets receive `bar`, `moduleName`, `settings` by property injection.
  The `bar` object provides `run()`, `showTooltip()`, `requestPopout()`,
  `barForeground`, `barSize`, `vertical`, and friends.

### Decision: keep the built-in bar as host

A `kind: "bar"` plugin can replace the whole bar, but then it must
reimplement the bar facade: per-monitor windows, exclusive zones, popout
coordination, tooltip plumbing, drag-reorder, transparency with
wallpaper-contrast text. The built-in bar already does all of that and
resolves widgets through the shared registry, so replacing every widget
plus the bar's theme section gives a fully Whiterose bar with zero
re-implementation risk. The full-bar option remains open (phase 6).

## Phases

### Phase 0: platform mapping (done)

Extracted the plugin API from the shell source: manifest schema, entry
points, widget injection, popout lifecycle, theme tokens, animation
constants, service singletons (Pipewire, UPower, Bluetooth, Hyprland,
SystemTray, Mpris, Networking).

### Phase 1: chrome via theme (done)

- `colors.toml`: near-black surfaces, off-white type, gray main accent,
  desaturated status colors, subtle two-stop border gradient.
- `theme/accents/*.toml`: one-line accent overrides used to generate the
  `whiterose-<accent>` variants.
- `shell.bar.toml`: bar at `background-alpha 0.45`, height 30.
- `shell.controls.toml`: hairline 1 px borders, low-alpha fills, accent
  reserved for focus and hover.
- Margins and paddings ride the shell's semantic spacing tokens, so they
  are consistent everywhere and scale with `[spacing] scale` and font size.

### Phase 2: bar widgets (done)

Eleven plugins, listed in the README. Notable behaviors:

- workspaces: dashes instead of numbers; focused dash widens and takes
  the accent (160 ms), occupied dashes sit at 65 percent, empty at 22.
- clock: format split on ":" with a breathing separator; click toggles
  the date; right click opens the timezone picker.
- audio: wheel adjusts, right click mutes, click opens a hairline slider
  popout with full keyboard control (arrows adjust, Enter mutes).
- battery/update: absent state means absent widget, not a placeholder.

### Phase 3: the menu (done)

`whiterose.menu` is a `menu` + `bar-widget` plugin. Data lives in
`Data.js` as a flat dotted-id tree (same convention as the stock JSONC),
so adding a menu item is one line. Features: type-to-filter across the
whole tree, breadcrumb, Backspace/Left to go up, Enter-twice confirm on
logout/restart/shutdown, 140 ms fade-and-lift entrance, scrim from the
theme, hint footer. Routes: `root`, `capture`, `style`, `toggle`,
`system` (alias `power`).

### Phase 4: integration (done)

- Omni stays the launcher; it gets a "/" bar button and an Apps row in
  the menu, both toggling the existing overlay.
- `install.sh` symlinks plugins (hot-reloadable), copies the theme
  (theme staging requires real directories), enables everything, and
  optionally replaces the bar layout with a timestamped backup.
- Keybindings: SUPER+ALT+SPACE and SUPER+ESCAPE now open the Whiterose
  menu (documented, reversible unbind/bindd pair in bindings.conf).

### Phase 5: polish and a11y passes (in progress)

- [x] Menu: fuzzy matching (scored subsequence, label matches first).
- [x] Media widget (Mpris): play state + truncated title, hidden when
      idle, click play/pause, right click next.
- [x] Bluetooth device picker popout (connect/disconnect/pair per
      device, keyboard driven).
- [x] Reduced motion: `pulse false` setting on the clock.
- [x] Brand: theme-adaptive rose logo as the menu button (light/dark
      variant chosen by bar foreground luminance).
- [ ] Focus-visible audit: verify `focus-*` tokens read clearly in both
      the Whiterose theme and stock themes.
- [ ] Menu: dynamic providers (themes list, power profiles) via Process.
- [ ] Network popout: list networks with connect/disconnect using
      `Quickshell.Networking`, replacing the nmtui jump.
- [ ] Notification center widget backed by the shell notification service.

### Phase 6: optional full bar (`kind: "bar"`)

Only worth it for layouts the host cannot express (split islands,
floating bar, per-section backgrounds). Requirements gathered from the
built-in bar: provide a `bar` facade (`barForeground`, `fontFamily`,
`vertical`, `barSize`, `run`, `showTooltip`/`hideTooltip`,
`requestPopout`/`releasePopout`), per-screen `PanelWindow` via
`Variants { model: Quickshell.screens }`, exclusive zone from the
cross-axis implicit size, and widget resolution through
`barWidgetRegistry.widgets[id].component`. Select with
`omarchy bar use whiterose.bar`; the shell falls back to the stock bar
if it fails to load.

## Verification checklist

```bash
omarchy-shell shell listPlugins        # all whiterose.* enabled, no errors
omarchy-shell shell debugBarGeometry   # every widget visible with size
omarchy bar layout --json              # layout as installed
hyprctl configerrors                   # after keybinding changes
```

Shell log: `/run/user/$UID/quickshell/by-id/<instance>/log.log`.
