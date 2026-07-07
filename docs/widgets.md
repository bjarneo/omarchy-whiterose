# Widget reference

Every widget is a plugin directory under `plugins/`. Settings are inline
keys on the widget's entry in `~/.config/omarchy/shell.json`, set them
with `omarchy bar set <id> <key> <value>`.

## whiterose.menu

Bar button (the Whiterose rose logo) plus the menu surface itself. The
logo ships in light and dark variants and follows the bar's foreground
luminance, so it stays visible on dark themes, light themes, and the
transparent bar's contrast mode.

- Left click: root menu. Right click: system section.
- Summon from anywhere:

```bash
omarchy-shell shell toggle whiterose.menu '{"menu":"root"}'
omarchy-shell shell toggle whiterose.menu '{"menu":"system"}'   # alias: power
```

Keys inside the menu: type to filter, Up/Down/Tab to move, Enter to run
or descend, Right to descend, Backspace/Left to go up, Esc to clear the
filter then close. Logout, restart, and shutdown ask for a second Enter.

Add or change items in `plugins/whiterose.menu/Data.js`. Entries use
dotted ids (`system.lock`); an entry without an `action` is a submenu.

## whiterose.workspaces

Dash indicators for Hyprland workspaces 1-10 (always shows 1-5).
Click a dash to focus. Focused = wide accent dash, occupied = dimmed
dash, empty = faint dash. Hovering a dash fires a 130 ms glitch (two
horizontal jitters and an opacity dip). Disable it for reduced motion:

```bash
omarchy bar set whiterose.workspaces glitch false --json
```

## whiterose.clock

| Setting | Default | Notes |
| --- | --- | --- |
| format | HH:mm | Split on ":" to get the breathing separator |
| formatAlt | ddd d MMM  HH:mm | Shown after a click |

Right click opens the timezone picker. Hover shows the full date.
For reduced motion, disable the breathing separator:

```bash
omarchy bar set whiterose.clock pulse false --json
```

## whiterose.active-window

| Setting | Default | Notes |
| --- | --- | --- |
| maxWidth | 320 | Elides in the middle beyond this |

Hidden on vertical bars and when nothing is focused.

## whiterose.audio

Wheel adjusts volume in 5 percent steps, right or middle click mutes,
left click opens the slider popout (arrows adjust, Enter mutes, Esc
closes). Uses the default Pipewire sink.

## whiterose.network

| Setting | Default |
| --- | --- |
| onClick | omarchy-launch-floating-terminal-with-presentation nmtui |

State comes from `omarchy-network-status --verbose` every 3 seconds.
The verbose mode reads interface state from the kernel (ip/iw), so it
stays correct on iwd-managed Wi-Fi where the nmcli-based non-verbose
mode (and the stock widget) report "disconnected". Tooltip shows SSID
and signal quality, or interface and IP on ethernet.

## whiterose.bluetooth

Left click opens the device picker: connected devices first, then
remembered ones. Click a device (or press Enter) to connect or
disconnect; unpaired devices are paired first. Right click on the bar
glyph toggles the adapter, as does the on/off label in the popout.
Hidden when no adapter exists.

## whiterose.media

| Setting | Default | Notes |
| --- | --- | --- |
| maxLength | 28 | Truncates "artist - title" beyond this |

Hidden until an MPRIS player has a track. Click toggles play/pause,
right click skips forward, middle click skips back. Prefers whichever
player is actually playing.

## whiterose.battery

| Setting | Default | Notes |
| --- | --- | --- |
| warnAt | 15 | Urgent tint below this while discharging |

Hidden entirely on machines without a battery. Click opens the system
menu.

## whiterose.omni

"/" button that toggles the Omni palette overlay (`omni` plugin).

## whiterose.power

Power glyph that opens the system section of the Whiterose menu.

## whiterose.update

Invisible until `omarchy-update-available` reports an update (checked
hourly), then a single urgent glyph. Click runs the update in a floating
terminal.
