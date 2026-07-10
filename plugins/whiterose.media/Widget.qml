import QtQuick
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

// Now playing. Prefers the actively playing MPRIS player, falls back to
// the first one with a track. Absent media, absent widget.
BarWidget {
  id: root
  moduleName: "whiterose.media"

  readonly property var player: {
    var players = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < players.length; i++) {
      if (players[i] && players[i].isPlaying) return players[i]
    }
    for (var j = 0; j < players.length; j++) {
      if (players[j] && players[j].trackTitle) return players[j]
    }
    return null
  }

  readonly property string title: player && player.trackTitle ? player.trackTitle : ""
  readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
  readonly property bool playing: player !== null && player.isPlaying

  readonly property string label: {
    var text = artist ? artist + " - " + title : title
    // Floor at 4 so `max - 3` below can never go negative on a bad setting.
    var max = Math.max(4, Number(setting("maxLength", 28)) || 28)
    return text.length > max ? text.slice(0, max - 3) + "..." : text
  }

  visible: !vertical && title !== ""
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: (root.playing ? "\u{f03e4}" : "\u{f040a}") + "  " + root.label
    dimmed: !root.playing
    fontSize: Style.font.bodySmall
    tooltipText: root.artist ? root.artist + " - " + root.title : root.title
    onPressed: function(mouseButton) {
      if (!root.player) return
      if (mouseButton === Qt.RightButton && root.player.canGoNext) root.player.next()
      else if (mouseButton === Qt.MiddleButton && root.player.canGoPrevious) root.player.previous()
      else root.player.togglePlaying()
    }
  }
}
