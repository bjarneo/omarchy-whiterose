import QtQuick
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Focused window title. Quiet by design: dimmed, elided, animates width.
// Hidden on vertical bars where a title cannot breathe.
BarWidget {
  id: root
  moduleName: "whiterose.active-window"

  readonly property var activeToplevel: ToplevelManager.activeToplevel
  readonly property string title: activeToplevel && activeToplevel.title ? activeToplevel.title : ""
  readonly property int maxWidth: Style.space(Number(setting("maxWidth", 320)))

  visible: !vertical && title !== ""
  implicitWidth: visible ? Math.min(label.implicitWidth, maxWidth) + Style.space(17) : 0
  implicitHeight: root.barSize

  Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

  Text {
    id: label
    anchors.centerIn: parent
    width: Math.min(implicitWidth, root.maxWidth)
    text: root.title
    color: root.bar ? root.bar.barForeground : Color.foreground
    opacity: 0.6
    elide: Text.ElideMiddle
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.bodySmall
  }
}
