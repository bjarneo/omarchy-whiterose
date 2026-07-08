#!/bin/bash
# Whiterose installer. Symlinks plugins and theme into omarchy's user
# config, rescans the shell plugin registry, and enables every plugin.
#
# Usage:
#   ./install.sh                    # install plugins + themes, choose a theme
#   ./install.sh --theme cyan       # install and apply whiterose-cyan
#   ./install.sh --theme whiterose  # install and apply the main gray theme
#   ./install.sh --bar              # also replace the bar layout (backs up shell.json)
#   ./install.sh --uninstall        # remove symlinks and restore nothing else

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugdir="$HOME/.config/omarchy/plugins"
themedir="$HOME/.config/omarchy/themes"
base_theme="whiterose"
selected_theme=""
replace_bar=false

theme_accents=(
  gray
  rose
  amber
  green
  cyan
  violet
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
  whiterose.omni
  whiterose.power
  whiterose.update
)
optional_plugins=(
  whiterose.active-window
)

die() {
  echo "error: $*" >&2
  exit 1
}

theme_name_for_accent() {
  local accent_name="$1"
  if [[ "$accent_name" == "gray" ]]; then
    printf '%s\n' "$base_theme"
  else
    printf '%s-%s\n' "$base_theme" "$accent_name"
  fi
}

read_accent_color() {
  local accent_name="$1"
  local file="$repo/theme/accents/$accent_name.toml"
  local line color

  [[ -f "$file" ]] || die "missing accent file: $file"
  while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*accent[[:space:]]*=[[:space:]]*\"(#[0-9A-Fa-f]{6})\"[[:space:]]*$ ]]; then
      color="${BASH_REMATCH[1]}"
      printf '%s\n' "${color,,}"
      return 0
    fi
  done <"$file"

  die "missing accent color in $file"
}

usage() {
  cat <<EOF
Usage: ./install.sh [--theme THEME] [--bar]
       ./install.sh --uninstall

Themes:
EOF
  for accent_name in "${theme_accents[@]}"; do
    local theme_name color label
    theme_name="$(theme_name_for_accent "$accent_name")"
    color="$(read_accent_color "$accent_name")"
    label="$accent_name"
    [[ "$accent_name" == "gray" ]] && label="gray, main"
    printf '  %-18s %s (%s)\n' "$theme_name" "$color" "$label"
  done
}

normalize_theme_selection() {
  local input="${1,,}"
  local accent_name theme_name

  for accent_name in "${theme_accents[@]}"; do
    theme_name="$(theme_name_for_accent "$accent_name")"
    if [[ "$input" == "$accent_name" || "$input" == "$theme_name" ]]; then
      printf '%s\n' "$theme_name"
      return 0
    fi
    if [[ "$accent_name" == "gray" && "$input" == "$base_theme-gray" ]]; then
      printf '%s\n' "$base_theme"
      return 0
    fi
  done

  die "unknown theme '$input'. Run ./install.sh --help to list themes"
}

choose_theme() {
  local answer index accent_name theme_name color

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
  for accent_name in "${theme_accents[@]}"; do
    theme_name="$(theme_name_for_accent "$accent_name")"
    color="$(read_accent_color "$accent_name")"
    if [[ "$accent_name" == "gray" ]]; then
      printf '  %d) %s (%s, main gray)\n' "$index" "$theme_name" "$color"
    else
      printf '  %d) %s (%s)\n' "$index" "$theme_name" "$color"
    fi
    ((index++))
  done

  read -r -p "Theme [1]: " answer || answer=""
  if [[ -z "$answer" ]]; then
    selected_theme="$base_theme"
    return 0
  fi

  if [[ "$answer" =~ ^[0-9]+$ ]]; then
    ((answer >= 1 && answer <= ${#theme_accents[@]})) || die "theme number out of range: $answer"
    accent_name="${theme_accents[$((answer - 1))]}"
    selected_theme="$(theme_name_for_accent "$accent_name")"
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

install_theme() {
  local accent_name="$1"
  local theme_name accent_color target

  theme_name="$(theme_name_for_accent "$accent_name")"
  accent_color="$(read_accent_color "$accent_name")"
  target="$themedir/$theme_name"

  rm -rf "${target:?}"
  cp -r "$repo/theme/$base_theme" "$target"
  apply_accent_to_theme "$target" "$accent_color"
  echo "copied theme $theme_name ($accent_name accent $accent_color)"
}

install_themes() {
  local accent_name
  for accent_name in "${theme_accents[@]}"; do
    install_theme "$accent_name"
  done
}

uninstall() {
  local accent_name theme_name
  for id in "${plugins[@]}" "${optional_plugins[@]}"; do
    [[ -L "$plugdir/$id" ]] && rm "$plugdir/$id" && echo "removed $id"
  done
  for accent_name in "${theme_accents[@]}"; do
    theme_name="$(theme_name_for_accent "$accent_name")"
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

# Menu/overlay plugins are enabled by presence in shell.json plugins[].
python3 - "$HOME/.config/omarchy/shell.json" <<'PY'
import json, sys, os
path = sys.argv[1]
config = {"version": 1}
if os.path.exists(path):
    with open(path) as f:
        config = json.load(f)
plugins = config.setdefault("plugins", [])
if not any(p.get("id") == "whiterose.menu" for p in plugins):
    plugins.append({"id": "whiterose.menu"})
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
        {"id": "omarchy.tray"},
        {"id": "whiterose.bluetooth"},
        {"id": "whiterose.network"},
        {"id": "whiterose.audio"},
        {"id": "whiterose.battery"},
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
  ./install.sh --theme cyan                   install and apply whiterose-cyan
  ./install.sh --theme whiterose --bar        apply main gray theme and replace the bar layout
  omarchy-shell shell toggle whiterose.menu '{"menu":"root"}'
EOF
