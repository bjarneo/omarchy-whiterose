# whiterose

A complete replacement UI for the Omarchy shell, built as plugins you own.
Minimal, quiet, keyboard-first, with a subtle hacker accent. Every color
comes from the active theme, so it restyles itself when you switch themes.

## Quick start

```bash
git clone <this repo> ~/Code/whiterose-omarchy
cd ~/Code/whiterose-omarchy
./install.sh          # plugins + theme
./install.sh --bar    # also replace the bar layout (backs up shell.json)
omarchy theme set whiterose
```

Open the menu:

```bash
omarchy-shell shell toggle whiterose.menu '{"menu":"root"}'
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
| whiterose.network | omarchy.network | Wi-Fi / ethernet state, SSID tooltip |
| whiterose.bluetooth | omarchy.bluetooth | Device picker popout; right click toggles power |
| whiterose.battery | omarchy.power | Charge glyph, urgent when low, hidden on desktops |
| whiterose.media | omarchy.media | MPRIS now playing, click play/pause, hidden when idle |
| whiterose.omni | (new) | "/" button that opens your Omni palette |
| whiterose.power | (new) | Power button into the system menu |
| whiterose.update | omarchy.system-update | Appears only when an update exists |

The stock `omarchy.tray` stays: tray icons are app-owned, there is nothing
to restyle. The Whiterose theme ships translucent bar chrome, hairline
controls, and a fully monochrome palette: graphite surfaces, near-white
identity, a white flash for alarms, and a grayscale terminal ramp.
Every text tone passes WCAG AA against the background.

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
./install.sh --uninstall
omarchy refresh shell     # restores the stock bar layout
omarchy theme set "Tokyo Night"
```
