import QtQuick
import qs.Commons
import qs.Ui

// Sun/moon toggle between a theme and its light twin. The glyph follows the
// active theme's background luminance (reactive through Color), so it stays
// correct however the theme was switched. Clicking applies the paired theme:
// `name` <-> `name-light`, with the stock catppuccin/latte pair special-cased.
// When no twin is installed, a notification says so instead of failing quietly.
BarWidget {
  id: root
  moduleName: "whiterose.mode"

  readonly property color themeBg: Color.background
  readonly property bool lightMode: (0.299 * themeBg.r + 0.587 * themeBg.g + 0.114 * themeBg.b) >= 0.5

  // Keep in sync with the toggle.lightmode action in whiterose.menu/Data.js.
  readonly property string toggleCommand: "t=$(cat \"$HOME/.local/state/omarchy/current/theme.name\" 2>/dev/null); [ -n \"$t\" ] || exit 0; case $t in catppuccin) n=catppuccin-latte ;; catppuccin-latte) n=catppuccin ;; *-light) n=${t%-light} ;; *) n=$t-light ;; esac; if [ -d \"$HOME/.config/omarchy/themes/$n\" ] || [ -d \"${OMARCHY_PATH:-$HOME/.local/share/omarchy}/themes/$n\" ]; then omarchy-theme-set \"$n\"; else notify-send \"Whiterose\" \"No $n theme installed\"; fi"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.lightMode ? "\u{f05a8}" : "\u{f0594}"
    tooltipText: root.lightMode ? "Switch to dark theme" : "Switch to light theme"
    onPressed: function() {
      if (root.bar) root.bar.run(root.toggleCommand)
    }
  }
}
