import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Output volume. Wheel adjusts, right click mutes, left click opens a
// hairline slider popout.
Panel {
  id: root
  moduleName: "whiterose.audio"
  // Same IPC surface as the stock panels: `omarchy-shell whiterose.audio
  // toggle`. After heavy plugin rescans the old instance's handler can
  // linger; omarchy-restart-shell clears it.
  ipcTarget: "whiterose.audio"

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

  readonly property string glyph: muted ? "\u{f075f}"
    : (volume < 0.01 ? "" : (volume < 0.5 ? "" : "\u{f057e}"))

  function setVolume(value) {
    if (sink && sink.audio) sink.audio.volume = Math.max(0, Math.min(1, value))
  }

  function toggleMute() {
    if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
  }

  PwObjectTracker { objects: root.sink ? [root.sink] : [] }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    dimmed: root.muted
    tooltipText: root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton || mouseButton === Qt.MiddleButton) root.toggleMute()
      else root.toggle()
    }
    onWheelMoved: function(delta) {
      root.setVolume(root.volume + (delta > 0 ? 0.05 : -0.05))
    }
  }

  KeyboardPanel {
    id: pop
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: pop.fittedContentWidth(Style.space(260))
    contentHeight: pop.fittedContentHeight(content.implicitHeight, Style.space(200))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) {
        var step = dy !== 0 ? (dy > 0 ? -0.05 : 0.05) : (dx > 0 ? 0.05 : -0.05)
        root.setVolume(root.volume + step)
      }
      onActivateRequested: root.toggleMute()

      Column {
        id: content
        width: parent.width
        spacing: Style.spacing.panelGap

        Item {
          width: parent.width
          height: Style.space(20)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "volume"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 2
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "muted" : Math.round(root.volume * 100) + "%"
            color: root.muted ? Color.muted : Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }

        // Hairline slider: 2px track, accent fill, generous hit area.
        Item {
          id: slider
          width: parent.width
          height: Style.space(24)

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Style.spaceReal(2)
            radius: height / 2
            color: Color.popups.text
            opacity: 0.15
          }

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * root.volume
            height: Style.spaceReal(2)
            radius: height / 2
            color: root.muted ? Color.muted : Color.accent

            Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
          }

          Rectangle {
            x: parent.width * root.volume - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(8)
            height: Style.space(8)
            radius: width / 2
            color: root.muted ? Color.muted : Color.accent
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: function(mouse) { root.setVolume(mouse.x / width) }
            onPositionChanged: function(mouse) {
              if (pressed) root.setVolume(Math.max(0, Math.min(1, mouse.x / width)))
            }
          }
        }

        Text {
          width: parent.width
          text: "wheel adjusts    right click mutes"
          color: Color.muted
          elide: Text.ElideRight
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
