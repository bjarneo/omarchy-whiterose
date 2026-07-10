# whiterose

A complete replacement UI for the Omarchy shell, built as plugins you own.
Minimal, quiet, keyboard-first, with a subtle hacker accent. Every color
comes from the active theme, so it restyles itself when you switch themes.

## Quick start

```bash
git clone <this repo> ~/Code/whiterose-omarchy
cd ~/Code/whiterose-omarchy
./install.sh                # plugins + themes, choose a theme
./install.sh --theme cyan    # apply whiterose-cyan without prompting
./install.sh --theme gruvbox # apply whiterose-gruvbox without prompting
./install.sh --theme light   # apply the light paper theme
./install.sh --bar           # also replace the bar layout (backs up shell.json)
./install.sh --force         # overwrite locally modified theme dirs
```

Open the menu:

```bash
omarchy-shell shell toggle whiterose.menu '{"menu":"root"}'
```

If the network popout cannot use NetworkManager, switch or repair the backend:

```bash
scripts/whiterose-network-backend fix-nm
scripts/whiterose-network-backend iwd
scripts/whiterose-network-backend iw
```

The installer symlinks plugins into `~/.config/omarchy/plugins/`, so edits
here hot-reload with `omarchy plugin rescan`.

## What you get

| Plugin | Replaces | What it is |
| --- | --- | --- |
| whiterose.menu | omarchy.menu | Rose-logo button + keyboard-first menu with fuzzy filter |
| whiterose.workspaces | omarchy.workspaces | Dash indicators, accent on focus |
| whiterose.clock | omarchy.clock | HH:mm with a breathing separator, click for date |
| whiterose.active-window | omarchy.active-window | Dimmed window title (built, not in the default layout) |
| whiterose.audio | omarchy.audio | Glyph + hairline slider popout, wheel volume |
| whiterose.network | omarchy.network | Wi-Fi / ethernet state, keyboard network picker |
| whiterose.bluetooth | omarchy.bluetooth | Device picker popout; right click toggles power |
| whiterose.battery | omarchy.power | Charge glyph, urgent when low, hidden on desktops |
| whiterose.media | omarchy.media | MPRIS now playing, click play/pause, hidden when idle |
| whiterose.mode | (new) | Sun/moon button that swaps the theme with its light/dark twin |
| whiterose.omni | (new) | "/" button that opens the Omarchy launcher |
| whiterose.power | (new) | Power button into the system menu |
| whiterose.update | omarchy.system-update | Appears only when an update exists |
| whiterose.notifications | omarchy.notifications | Pending/recent notifications, DND toggle |

The stock `omarchy.tray` stays: tray icons are app-owned, there is nothing
to restyle. The stock `omarchy.osd` stays enabled so volume, display
brightness, and keyboard backlight keys still show progress overlays. The
main Whiterose theme ships translucent bar chrome, hairline
controls, and a fully monochrome palette: graphite surfaces, a gray accent,
a white flash for alarms, and a grayscale terminal ramp. Accent variants
keep that palette and override only the accent color. `whiterose-gruvbox`
keeps the same gray surfaces and wallpaper, but swaps in a muted Gruvbox
color ramp that still sits quietly on gray.

Every theme also installs a light twin (`whiterose-light`,
`whiterose-cyan-light`, ...): the same monochrome identity inverted onto
paper, with ink hairlines and a black attention flash. Flip between twins
with the sun/moon bar button or the menu's Light mode row.

## Keybindings

The installer does not touch keybindings. Omarchy's active bindings are
Lua (`~/.config/hypr/bindings.lua`); the legacy `bindings.conf` is not
sourced. This repo's setup added:

```lua
hl.unbind("SUPER + ALT + SPACE")
hl.bind(
	"SUPER + ALT + SPACE",
	hl.dsp.exec_cmd([[omarchy-shell shell toggle whiterose.menu '{"menu":"system"}']]),
	{ description = "Whiterose system menu" }
)
hl.unbind("SUPER + ESCAPE")
hl.bind(
	"SUPER + ESCAPE",
	hl.dsp.exec_cmd([[omarchy-shell shell toggle whiterose.menu '{"menu":"system"}']]),
	{ description = "Whiterose system menu" }
)
```

Use `'{"menu":"root"}'` for the full menu instead of the system section.

## Docs

- [Roadmap and architecture](docs/roadmap.md)
- [Widget reference and settings](docs/widgets.md)
- [Theming](docs/theming.md)

## Uninstall

```bash
./install.sh --uninstall  # switches to Tokyo Night first if a whiterose theme is active
omarchy refresh shell     # restores the stock bar layout
```
