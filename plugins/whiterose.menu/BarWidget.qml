import QtQuick
import qs.Commons
import qs.Ui

// Omarchy logo button. The variant follows the bar's foreground
// luminance, so it reads like text on dark themes, light themes, and the
// transparent bar's wallpaper-contrast mode alike. Left click opens the
// menu at root, right click jumps to the system section.
BarWidget {
  id: root
  moduleName: "whiterose.menu"

  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property bool lightForeground: (0.299 * fg.r + 0.587 * fg.g + 0.114 * fg.b) >= 0.5

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: " "
    keepSpace: true
    fixedWidth: Style.space(28)
    tooltipText: "Menu"
    onPressed: function(mouseButton) {
      if (!root.bar) return
      if (mouseButton === Qt.RightButton)
        root.bar.run("omarchy-shell shell toggle whiterose.menu '{\"menu\":\"system\"}'")
      else
        root.bar.run("omarchy-shell shell toggle whiterose.menu '{\"menu\":\"root\"}'")
    }

    Image {
      anchors.centerIn: parent
      width: Style.space(16)
      height: Style.space(16)
      source: root.lightForeground ? Qt.resolvedUrl("logo-light.png") : Qt.resolvedUrl("logo-dark.png")
      sourceSize: Qt.size(Style.space(32), Style.space(32))
      smooth: true
      opacity: button.tooltipHovered ? 1 : 0.88

      Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
  }
}
