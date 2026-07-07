import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "whiterose.power"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u{f0425}"
    tooltipText: "System"
    onPressed: function() {
      if (root.bar) root.bar.run("omarchy-shell shell toggle whiterose.menu '{\"menu\":\"system\"}'")
    }
  }
}
