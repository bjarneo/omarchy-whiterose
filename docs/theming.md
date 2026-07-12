# Theming

Whiterose never hardcodes a color. Widgets read the shell's `Color.*`
and `Style.*` singletons, which the shell fills from the active theme's
`colors.toml` and `shell.toml`. Switch themes and the whole suite
follows, including the menu, popouts, and bar chrome.

## The Whiterose theme

`theme/whiterose/` ships the main gray theme:

| File | Purpose |
| --- | --- |
| colors.toml | Monochrome: graphite surfaces, gray accent, AA contrast |
| shell.bar.toml | Bar veil 0.72 alpha; attention is a pure white flash |
| shell.controls.toml | Dim hairlines that switch to near-white on hover/focus |
| neovim.lua | aether.nvim (bjarneo/aether.nvim, v3) fed the same palette |
| backgrounds/ | Subtle dark-gray maze texture |

`neovim.lua` is hand-written rather than generated: it follows the
aether template (`~/Code/aether` templates/neovim.lua) and passes a
palette to `require("aether").setup()`. It deliberately runs hotter than
the shell: a darker background (`#121212`) and a wider token ramp
(fg 15.3:1) so syntax groups separate by tone in an editor where the
shell's gentler spread would read flat. Omarchy symlinks it into LazyVim
via `~/.config/nvim/lua/plugins/theme.lua` on `omarchy theme set`.

The main theme is fully monochrome, adopted from an aether-generated
grayscale theme and lifted for contrast (the source foreground measured
4.7:1; this one is 10.7:1). There is no hue anywhere: the identity is
light itself. Accent `#e8e8e8` marks focus and selection, the alarm is
a pure white flash, and the ANSI ramp is grayscale by design, so
terminals render in tone rather than color.

Accent variants live in `theme/accents/*.toml` as tiny overrides with two
keys: `accent` for the dark base and `light_accent` for the light one. The
installer copies the base theme into real Omarchy theme directories and
patches only accent-driven fields: `Color.accent`, Hyprland's active border,
shell control focus/selection, and the Neovim accent/cursor. The gray accent
is the main `whiterose` theme; other accents install as `whiterose-<accent>`
plus a `whiterose-<accent>-light` twin.

Richer variants live in `theme/variants/*.toml`. `whiterose-gruvbox` keeps
the same gray backgrounds, foreground ramp, bar chrome, and wallpaper, then
overrides only color roles with desaturated Gruvbox-inspired reds, yellows,
greens, blues, and purples that pass AA contrast on the gray base.
`whiterose-gruvbox-light` does the same on paper with a deeper, AA-checked
gruvbox-light ramp from `theme/variants/gruvbox-light.toml`.

Accessibility: every text tone clears WCAG AA against `bg` (#1e1e1e):
fg 10.7:1, dark_fg 6.9:1, muted 5.2:1, accent 13.6:1, white attention
15.3:1. If you darken `muted` for looks, keep it at or above 4.5:1; it
colors every caption and hint in the suite.

## Light mode

`theme/whiterose-light/` is a second base theme: the same monochrome
identity inverted onto warm paper. `colors.toml` carries `mode = "light"`,
which Omarchy propagates on `omarchy theme set` (GNOME color-scheme,
terminals, Neovim), so a light theme is simply a theme whose palette is
light; there is no separate runtime switch. The installer composes every
accent and variant against both bases, so each theme has a twin named
`<theme>-light`.

The light palette keeps the dark theme's discipline, mirrored: ink
hairlines, a black attention flash, and a grayscale ANSI ramp spread
dark-on-light. Contrast on bg (#f4f2ee): fg 12.8:1, dark_fg 7.9:1,
muted 4.6:1, accent 11.8:1, black attention 18.8:1. Light accent values
in `theme/accents/*.toml` all clear 4.5:1 on paper.

Switch twins with the `whiterose.mode` bar button, the menu's Light mode
row, or by hand:

```bash
omarchy theme set whiterose-light
omarchy theme set whiterose-cyan-light
```

The `shell.<section>.toml` files replace only that section of the
generated `shell.toml`, so the theme keeps inheriting upstream defaults
for everything it does not opine on.

## Make your own

1. Create `~/.config/omarchy/themes/<name>/colors.toml` (real directory,
   not a symlink). Start from `theme/whiterose/colors.toml`.
2. Optionally add `shell.<section>.toml` overrides. Sections:
   `bar`, `controls`, `popups`, `tooltip`, `notifications`, `launcher`,
   `menu`, `polkit`, `lock`, `image-picker`, `spacing`, `font`.
3. Drop one or more images into `backgrounds/`.
4. Apply: `omarchy theme set <name>`.

Useful knobs:

```toml
[bar]
background-alpha = 0.72   # Whiterose default bar translucency

[spacing]
scale = 1.1               # more breathing room everywhere

[font]
base-size = 13            # rescales the whole type ramp
```

Two transparency modes exist. The theme's `background-alpha` draws a
firm dark veil behind the bar (Whiterose uses 0.72, needs
`omarchy bar transparent false`). Fully transparent with
wallpaper-contrast text is the shell feature `omarchy bar transparent
true`; it ignores the theme veil entirely.

## Accent discipline

The suite uses `Color.accent` for: focused workspace, menu selection
bar, slider fill, prompt glyph, connected bluetooth. `Color.urgent` is
reserved for: low battery, update available, confirm-to-shutdown. Keep
that split when restyling; it is what keeps the bar quiet. The Whiterose
palette can afford a bright accent exactly because it appears in so few
places.
