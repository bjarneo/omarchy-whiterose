import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Clock with a softly pulsing separator. When the configured format contains
// a ":" the parts render around a breathing colon; otherwise it is a plain
// label. Click toggles the alternate (date) format.
BarWidget {
  id: root
  moduleName: "whiterose.clock"

  property bool alt: false
  property date displayDate: clock.date

  readonly property string format: String(setting("format", "HH:mm"))
  readonly property string formatAlt: String(setting("formatAlt", "ddd d MMM  HH:mm"))
  readonly property int splitAt: format.indexOf(":")
  // Set `pulse` to false on the layout entry for reduced motion.
  readonly property bool pulseEnabled: setting("pulse", true) === true
  readonly property bool pulsing: !alt && splitAt > 0

  readonly property string leftText: Qt.formatDateTime(displayDate, pulsing ? format.slice(0, splitAt) : (alt ? formatAlt : format))
  readonly property string rightText: pulsing ? Qt.formatDateTime(displayDate, format.slice(splitAt + 1)) : ""

  readonly property color textColor: bar ? bar.barForeground : Color.foreground

  // Clickable through the bar's module click plumbing.
  function triggerPress(button) {
    if (button === Qt.RightButton && root.bar) root.bar.run("omarchy-menu-timezone")
    else alt = !alt
  }

  property bool tooltipHovered: hover.hovered

  HoverHandler {
    id: hover
    onHoveredChanged: {
      if (!root.bar) return
      if (hovered) root.bar.showTooltip(root, Qt.formatDateTime(root.displayDate, "dddd d MMMM yyyy"))
      else root.bar.hideTooltip(root)
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.displayDate = date
  }

  implicitWidth: row.implicitWidth + Style.spaceReal(17.5)
  implicitHeight: root.barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 0

    Text {
      text: root.leftText
      color: root.textColor
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      visible: root.pulsing
      text: ":"
      color: root.textColor
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter

      SequentialAnimation on opacity {
        running: root.pulsing && root.pulseEnabled && root.visible
        loops: Animation.Infinite
        onRunningChanged: if (!running) parent.opacity = 1
        NumberAnimation { from: 1; to: 0.3; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.3; to: 1; duration: 900; easing.type: Easing.InOutSine }
      }
    }

    Text {
      visible: root.pulsing
      text: root.rightText
      color: root.textColor
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
