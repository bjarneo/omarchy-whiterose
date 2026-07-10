#!/bin/bash
# Whiterose installer. Symlinks plugins and theme into omarchy's user
# config, rescans the shell plugin registry, and enables every plugin.
#
# Usage:
#   ./install.sh                    # install plugins + themes, choose a theme
#   ./install.sh --theme cyan       # install and apply whiterose-cyan
#   ./install.sh --theme gruvbox    # install and apply whiterose-gruvbox
#   ./install.sh --theme light      # install and apply the light paper theme
#   ./install.sh --theme whiterose  # install and apply the main gray theme
#   ./install.sh --bar              # also replace the bar layout (backs up shell.json)
#   ./install.sh --force            # overwrite locally modified theme dirs
#   ./install.sh --uninstall        # remove symlinks and restore nothing else
#
# Every theme installs in a dark and a light variant so the whiterose.mode
# widget (and the menu's Light mode row) can flip between them.

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugdir="$HOME/.config/omarchy/plugins"
themedir="$HOME/.config/omarchy/themes"
base_theme="whiterose"
manifest_name=".whiterose-manifest"
selected_theme=""
replace_bar=false
force=false

theme_options=(
  gray
  light
  rose
  rose-light
  amber
  amber-light
  green
  green-light
  cyan
  cyan-light
  violet
  violet-light
  gruvbox
  gruvbox-light
)

# Enabling a bar-widget plugin also adds it to the bar layout (the shell
# treats enabled and present as the same thing), so opt-in widgets like
# active-window are linked but not enabled here.
plugins=(
  whiterose.menu
  whiterose.workspaces
  whiterose.clock
  whiterose.audio
  whiterose.network
  whiterose.bluetooth
  whiterose.battery
  whiterose.media
  whiterose.mode
  whiterose.omni
  whiterose.power
  whiterose.update
  whiterose.notifications
)
optional_plugins=(
  whiterose.active-window
)

die() {
  echo "error: $*" >&2
  exit 1
}

# "gray" and "light" are the two base themes; every other option composes on
# top of one of them. A trailing "-light" selects the light base.
option_is_light() {
  [[ "$1" == "light" || "$1" == *-light ]]
}

is_base_option() {
  [[ "$1" == "gray" || "$1" == "light" ]]
}

base_dir_for_option() {
  if option_is_light "$1"; then
    printf '%s\n' "$repo/theme/$base_theme-light"
  else
    printf '%s\n' "$repo/theme/$base_theme"
  fi
}

theme_name_for_option() {
  local option="$1"
  if [[ "$option" == "gray" ]]; then
    printf '%s\n' "$base_theme"
  else
    printf '%s-%s\n' "$base_theme" "$option"
  fi
}

theme_file_for_option() {
  local option="$1"
  local stem="${option%-light}"

  if is_base_option "$option"; then
    printf '%s\n' "$(base_dir_for_option "$option")/colors.toml"
  elif [[ -f "$repo/theme/variants/$option.toml" ]]; then
    printf '%s\n' "$repo/theme/variants/$option.toml"
  elif [[ -f "$repo/theme/accents/$stem.toml" ]]; then
    printf '%s\n' "$repo/theme/accents/$stem.toml"
  else
    die "missing theme override file for $option"
  fi
}

is_full_theme_option() {
  [[ -f "$repo/theme/variants/$1.toml" ]]
}

# Accent files carry both modes: `accent` for the dark base, `light_accent`
# for the light one. Full variants and bases read their own `accent` key.
accent_key_for_option() {
  local option="$1"
  if ! is_base_option "$option" && ! is_full_theme_option "$option" && option_is_light "$option"; then
    printf '%s\n' "light_accent"
  else
    printf '%s\n' "accent"
  fi
}

theme_label_for_option() {
  local option="$1"
  local stem="${option%-light}"

  if [[ "$option" == "gray" ]]; then
    printf '%s\n' "gray, main"
  elif [[ "$option" == "light" ]]; then
    printf '%s\n' "paper, light"
  elif is_full_theme_option "$option"; then
    if option_is_light "$option"; then
      printf '%s\n' "$stem colors, light"
    else
      printf '%s\n' "$option colors"
    fi
  elif option_is_light "$option"; then
    printf '%s\n' "$stem accent, light"
  else
    printf '%s\n' "$option accent"
  fi
}

read_theme_accent_color() {
  local option="$1"
  local file key
  local line color

  file="$(theme_file_for_option "$option")"
  key="$(accent_key_for_option "$option")"
  [[ -f "$file" ]] || die "missing theme file: $file"
  while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"(#[0-9A-Fa-f]{6})\"[[:space:]]*$ ]]; then
      color="${BASH_REMATCH[1]}"
      printf '%s\n' "${color,,}"
      return 0
    fi
  done <"$file"

  die "missing $key color in $file"
}

usage() {
  cat <<EOF
Usage: ./install.sh [--theme THEME] [--bar] [--force]
       ./install.sh --uninstall

--force overwrites installed theme directories even when they were made by
hand or locally modified (including installs from before checksum manifests).

Themes:
EOF
  for option in "${theme_options[@]}"; do
    local theme_name color label
    theme_name="$(theme_name_for_option "$option")"
    color="$(read_theme_accent_color "$option")"
    label="$(theme_label_for_option "$option")"
    printf '  %-18s %s (%s)\n' "$theme_name" "$color" "$label"
  done
}

normalize_theme_selection() {
  local input="${1,,}"
  local option theme_name

  for option in "${theme_options[@]}"; do
    theme_name="$(theme_name_for_option "$option")"
    if [[ "$input" == "$option" || "$input" == "$theme_name" ]]; then
      printf '%s\n' "$theme_name"
      return 0
    fi
    if [[ "$option" == "gray" && "$input" == "$base_theme-gray" ]]; then
      printf '%s\n' "$base_theme"
      return 0
    fi
  done

  die "unknown theme '$input'. Run ./install.sh --help to list themes"
}

choose_theme() {
  local answer index option theme_name color label

  if [[ -n "$selected_theme" ]]; then
    selected_theme="$(normalize_theme_selection "$selected_theme")"
    return 0
  fi

  if [[ ! -t 0 || ! -t 1 ]]; then
    selected_theme="$base_theme"
    return 0
  fi

  echo "Choose Whiterose theme:"
  index=1
  for option in "${theme_options[@]}"; do
    theme_name="$(theme_name_for_option "$option")"
    color="$(read_theme_accent_color "$option")"
    label="$(theme_label_for_option "$option")"
    printf '  %d) %s (%s, %s)\n' "$index" "$theme_name" "$color" "$label"
    ((index++))
  done

  read -r -p "Theme [1]: " answer || answer=""
  if [[ -z "$answer" ]]; then
    selected_theme="$base_theme"
    return 0
  fi

  if [[ "$answer" =~ ^[0-9]+$ ]]; then
    ((answer >= 1 && answer <= ${#theme_options[@]})) || die "theme number out of range: $answer"
    option="${theme_options[$((answer - 1))]}"
    selected_theme="$(theme_name_for_option "$option")"
    return 0
  fi

  selected_theme="$(normalize_theme_selection "$answer")"
}

apply_accent_to_theme() {
  local target="$1"
  local accent_color="$2"

  python3 - "$target" "$accent_color" <<'PY'
from pathlib import Path
import re
import sys

target = Path(sys.argv[1])
accent = sys.argv[2].lower()

if not re.fullmatch(r"#[0-9a-f]{6}", accent):
    raise SystemExit(f"invalid accent color: {accent}")

accent_hex = accent[1:]

def rewrite(path, callback):
    text = path.read_text()
    path.write_text(callback(text))

def sub_required(text, pattern, replacement, label, count=1):
    text, changed = re.subn(pattern, replacement, text, count=count, flags=re.MULTILINE)
    if changed != count:
        raise SystemExit(f"expected {count} replacement(s) for {label}, got {changed}")
    return text

def replace_color_key(text, key, color):
    pattern = rf"^([ \t]*{re.escape(key)}[ \t]*=[ \t]*)\"#[0-9a-fA-F]{{6}}\""
    return sub_required(text, pattern, lambda match: f'{match.group(1)}"{color}"', key)

def rewrite_colors(text):
    text = replace_color_key(text, "accent", accent)
    return sub_required(
        text,
        r'^([ \t]*hyprland_active_border[ \t]*=[ \t]*)"rgba\([0-9a-fA-F]{6}ee\)',
        lambda match: f'{match.group(1)}"rgba({accent_hex}ee)',
        "hyprland active border",
    )

def rewrite_controls(text):
    for key in (
        "hover-cursor-color",
        "hover-cursor-border",
        "focus-color",
        "focus-border",
        "selected-color",
        "selected-border",
    ):
        text = replace_color_key(text, key, accent)
    return text

def rewrite_neovim(text):
    for key in ("accent", "cursor"):
        text = replace_color_key(text, key, accent)
    return text

rewrite(target / "colors.toml", rewrite_colors)
rewrite(target / "shell.controls.toml", rewrite_controls)
rewrite(target / "neovim.lua", rewrite_neovim)
PY
}

apply_color_variant_to_theme() {
  local target="$1"
  local variant_file="$2"

  python3 - "$target" "$variant_file" <<'PY'
from pathlib import Path
import re
import sys

target = Path(sys.argv[1])
variant_file = Path(sys.argv[2])

color_keys = {
    "accent",
    "red",
    "yellow",
    "orange",
    "green",
    "cyan",
    "blue",
    "magenta",
    "brown",
    "bright_red",
    "bright_yellow",
    "bright_green",
    "bright_cyan",
    "bright_blue",
    "bright_magenta",
    "hyprland_active_border",
}
control_keys = {
    "hover-cursor-color",
    "hover-cursor-border",
    "focus-color",
    "focus-border",
    "selected-color",
    "selected-border",
}
neovim_keys = {
    "red",
    "yellow",
    "orange",
    "green",
    "cyan",
    "blue",
    "purple",
    "brown",
    "bright_red",
    "bright_yellow",
    "bright_green",
    "bright_cyan",
    "bright_blue",
    "bright_purple",
    "accent",
    "cursor",
}

def parse_overrides(path):
    overrides = {}
    for line_number, raw_line in enumerate(path.read_text().splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        match = re.fullmatch(r'([A-Za-z0-9_-]+)\s*=\s*"([^"]+)"', line)
        if not match:
            raise SystemExit(f"{path}:{line_number}: expected key = \"value\"")
        key, value = match.groups()
        if key in overrides:
            raise SystemExit(f"{path}:{line_number}: duplicate key {key}")
        overrides[key] = value.lower()
    return overrides

def validate_color(key, value):
    if key == "hyprland_active_border":
        if not re.fullmatch(r"rgba\([0-9a-f]{6}[0-9a-f]{2}\) rgba\([0-9a-f]{6}[0-9a-f]{2}\) [0-9]+deg", value):
            raise SystemExit(f"invalid hyprland_active_border: {value}")
        return
    if not re.fullmatch(r"#[0-9a-f]{6}", value):
        raise SystemExit(f"invalid color for {key}: {value}")

def sub_required(text, pattern, replacement, label, count=1):
    text, changed = re.subn(pattern, replacement, text, count=count, flags=re.MULTILINE)
    if changed != count:
        raise SystemExit(f"expected {count} replacement(s) for {label}, got {changed}")
    return text

def replace_string_key(text, key, value):
    pattern = rf"^([ \t]*{re.escape(key)}[ \t]*=[ \t]*)\"[^\"]*\""
    return sub_required(text, pattern, lambda match: f'{match.group(1)}"{value}"', key)

overrides = parse_overrides(variant_file)
colors = (target / "colors.toml").read_text()
controls = (target / "shell.controls.toml").read_text()
neovim = (target / "neovim.lua").read_text()

for key, value in overrides.items():
    if key in color_keys:
        validate_color(key, value)
        colors = replace_string_key(colors, key, value)
    elif key in control_keys:
        validate_color(key, value)
        controls = replace_string_key(controls, key, value)
    elif key.startswith("neovim_") and key[len("neovim_"):] in neovim_keys:
        neovim_key = key[len("neovim_"):]
        validate_color(key, value)
        neovim = replace_string_key(neovim, neovim_key, value)
    else:
        raise SystemExit(f"unknown variant override: {key}")

(target / "colors.toml").write_text(colors)
(target / "shell.controls.toml").write_text(controls)
(target / "neovim.lua").write_text(neovim)
PY
}

# Installed theme dirs get a checksum manifest so a later run can tell its
# own output from local edits. No manifest (hand-made dir or pre-manifest
# install) or a checksum mismatch means we refuse to overwrite unless
# --force is passed.
theme_checksums() {
  (cd "$1" && find . -type f ! -name "$manifest_name" -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum)
}

write_theme_manifest() {
  theme_checksums "$1" >"$1/$manifest_name"
}

overwrite_allowed() {
  local target="$1"
  [[ -d "$target" ]] || return 0
  [[ "$force" == true ]] && return 0
  [[ -f "$target/$manifest_name" ]] || return 1
  diff -q <(theme_checksums "$target") "$target/$manifest_name" >/dev/null 2>&1
}

generate_theme_preview() {
  local target="$1"
  python3 "$repo/scripts/whiterose-theme-preview" "$target" ||
    echo "warning: preview generation failed for $target" >&2
}

install_theme() {
  local option="$1"
  local theme_name accent_color target base_dir

  theme_name="$(theme_name_for_option "$option")"
  accent_color="$(read_theme_accent_color "$option")"
  base_dir="$(base_dir_for_option "$option")"
  target="$themedir/$theme_name"

  if ! overwrite_allowed "$target"; then
    echo "skipped theme $theme_name: not generated by this installer or locally modified (rerun with --force to overwrite)" >&2
    return 0
  fi

  rm -rf "${target:?}"
  cp -r "$base_dir" "$target"
  if is_base_option "$option"; then
    echo "copied theme $theme_name (base, accent $accent_color)"
  elif is_full_theme_option "$option"; then
    apply_color_variant_to_theme "$target" "$(theme_file_for_option "$option")"
    echo "copied theme $theme_name ($option colors $accent_color)"
  else
    apply_accent_to_theme "$target" "$accent_color"
    echo "copied theme $theme_name ($option accent $accent_color)"
  fi
  generate_theme_preview "$target"
  write_theme_manifest "$target"
}

install_themes() {
  local option
  for option in "${theme_options[@]}"; do
    install_theme "$option"
  done
}

uninstall() {
  local option theme_name current
  for id in "${plugins[@]}" "${optional_plugins[@]}"; do
    [[ -L "$plugdir/$id" ]] && rm "$plugdir/$id" && echo "removed $id"
  done
  # Do not delete the theme the shell is currently running on.
  current=""
  [[ -f "$HOME/.local/state/omarchy/current/theme.name" ]] &&
    current="$(<"$HOME/.local/state/omarchy/current/theme.name")"
  if [[ "$current" == "$base_theme" || "$current" == "$base_theme"-* ]]; then
    echo "switching away from $current before removing themes"
    omarchy-theme-set tokyo-night ||
      echo "warning: theme switch failed; run: omarchy theme set 'Tokyo Night'" >&2
  fi
  for option in "${theme_options[@]}"; do
    theme_name="$(theme_name_for_option "$option")"
    [[ -d "$themedir/$theme_name" ]] && rm -rf "${themedir:?}/$theme_name" && echo "removed theme $theme_name"
  done
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  echo "Whiterose uninstalled. Restore your bar with: omarchy refresh shell"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bar)
      replace_bar=true
      ;;
    --force)
      force=true
      ;;
    --theme)
      [[ $# -ge 2 ]] || die "--theme needs a value"
      selected_theme="$2"
      shift
      ;;
    --uninstall)
      uninstall
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

choose_theme

mkdir -p "$plugdir" "$themedir"

for id in "${plugins[@]}" "${optional_plugins[@]}"; do
  ln -sfT "$repo/plugins/$id" "$plugdir/$id"
  echo "linked $id"
done

# Themes must be real directories (omarchy-theme-set stages a copy).
install_themes

omarchy-shell shell rescanPlugins >/dev/null

for id in "${plugins[@]}"; do
  omarchy-shell shell setPluginEnabled "$id" true >/dev/null
done

# Menu/overlay plugins are enabled by presence in shell.json plugins[]. Keep
# the stock OSD enabled so media and brightness keys can show progress.
python3 - "$HOME/.config/omarchy/shell.json" <<'PY'
import json, sys, os
path = sys.argv[1]
config = {"version": 1}
if os.path.exists(path):
    with open(path) as f:
        config = json.load(f)
plugins = config.setdefault("plugins", [])
for plugin_id in ("whiterose.menu", "omarchy.osd"):
    if not any(p.get("id") == plugin_id for p in plugins):
        plugins.append({"id": plugin_id})
with open(path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PY
omarchy-shell shell reloadConfig >/dev/null
echo "plugins enabled"

if [[ "$replace_bar" == true ]]; then
  shelljson="$HOME/.config/omarchy/shell.json"
  if [[ -f "$shelljson" ]]; then
    cp "$shelljson" "$shelljson.bak.$(date +%s)"
    # Keep the five newest backups; these accumulate one per --bar run.
    ls -1t "$shelljson".bak.* 2>/dev/null | tail -n +6 | xargs -r rm --
    echo "backed up shell.json"
  fi
  python3 - "$shelljson" <<'PY'
import json, sys, os
path = sys.argv[1]
config = {"version": 1}
if os.path.exists(path):
    with open(path) as f:
        config = json.load(f)
bar = config.setdefault("bar", {})
bar["layout"] = {
    "left": [
        {"id": "whiterose.menu"},
        {"id": "whiterose.workspaces"},
    ],
    "center": [
        {"id": "whiterose.clock"},
    ],
    "right": [
        {"id": "whiterose.media"},
        {"id": "whiterose.update"},
        {"id": "whiterose.notifications"},
        {"id": "omarchy.tray"},
        {"id": "whiterose.bluetooth"},
        {"id": "whiterose.network"},
        {"id": "whiterose.audio"},
        {"id": "whiterose.battery"},
        {"id": "whiterose.mode"},
        {"id": "whiterose.omni"},
        {"id": "whiterose.power"},
    ],
}
bar["centerAnchor"] = "whiterose.clock"
bar["transparent"] = True
with open(path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PY
  omarchy-shell shell reloadConfig >/dev/null
  echo "bar layout replaced (previous shell.json backed up)"
fi

omarchy theme set "$selected_theme"
echo "theme applied: $selected_theme"

cat <<'EOF'

Done. Useful commands:
  ./install.sh --theme gruvbox                install and apply whiterose-gruvbox
  ./install.sh --theme cyan                   install and apply whiterose-cyan
  ./install.sh --theme light                  install and apply the light paper theme
  ./install.sh --theme whiterose --bar        apply main gray theme and replace the bar layout
  omarchy-shell shell toggle whiterose.menu '{"menu":"root"}'

Every theme has a light twin (whiterose-cyan-light, ...). Flip between them
with the sun/moon bar button or the menu's Light mode row.
EOF
