import QtQuick
import qs.Commons
import qs.Ui

// "/" toggles Omni -- the search affordance every terminal user already
// has in muscle memory.
BarWidget {
  id: root
  moduleName: "whiterose.omni"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "/"
    tooltipText: "Omni"
    horizontalMargin: 8.5
    verticalPadding: 6
    onPressed: function() {
      if (root.bar) root.bar.run("omarchy-shell shell toggle omni '{}'")
    }
  }
}
