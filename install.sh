#!/bin/bash
# Whiterose installer. Symlinks plugins and theme into omarchy's user
# config, rescans the shell plugin registry, and enables every plugin.
#
# Usage:
#   ./install.sh              # install plugins + theme
#   ./install.sh --bar        # also replace the bar layout (backs up shell.json)
#   ./install.sh --uninstall  # remove symlinks and restore nothing else

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugdir="$HOME/.config/omarchy/plugins"
themedir="$HOME/.config/omarchy/themes"

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

uninstall() {
  for id in "${plugins[@]}" "${optional_plugins[@]}"; do
    [[ -L "$plugdir/$id" ]] && rm "$plugdir/$id" && echo "removed $id"
  done
  [[ -d "$themedir/whiterose" ]] && rm -rf "$themedir/whiterose" && echo "removed theme"
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  echo "Whiterose uninstalled. Restore your bar with: omarchy refresh shell"
  exit 0
}

[[ "${1:-}" == "--uninstall" ]] && uninstall

mkdir -p "$plugdir" "$themedir"

for id in "${plugins[@]}" "${optional_plugins[@]}"; do
  ln -sfT "$repo/plugins/$id" "$plugdir/$id"
  echo "linked $id"
done

# Themes must be real directories (omarchy-theme-set stages a copy).
rm -rf "$themedir/whiterose"
cp -r "$repo/theme/whiterose" "$themedir/whiterose"
echo "copied theme whiterose"

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

if [[ "${1:-}" == "--bar" ]]; then
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

cat <<'EOF'

Done. Useful commands:
  omarchy theme set whiterose                 apply the Whiterose theme
  ./install.sh --bar                          replace the bar layout
  omarchy-shell shell toggle whiterose.menu '{"menu":"root"}'
EOF
