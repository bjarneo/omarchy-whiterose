import QtQuick
import qs.Commons
import qs.Ui

// Uses the stock omarchy.notifications service for DBus ownership, popup
// toasts, history, image caching, and DND persistence. This widget only
// replaces the bar affordance and history popout.
Panel {
  id: root
  moduleName: "whiterose.notifications"
  ipcTarget: "whiterose.notifications"

  property var notificationService: null
  property string activeTab: "pending"
  property int cursor: 0

  readonly property var hostShell: bar && bar.shell ? bar.shell : null
  readonly property int pendingCount: notificationService ? notificationService.pendingModel.count : 0
  readonly property int pastCount: notificationService ? notificationService.pastModel.count : 0
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : false
  readonly property int activeCount: activeTab === "pending" ? pendingCount : pastCount
  readonly property var activeModel: !notificationService ? null
    : (activeTab === "pending" ? notificationService.pendingModel : notificationService.pastModel)

  readonly property string glyph: dnd ? "\u{f009b}"
    : (pendingCount > 0 ? "\u{f116b}" : "\u{f009a}")

  function refreshService() {
    if (!hostShell) {
      notificationService = null
      return
    }
    var service = null
    if (typeof hostShell.firstPartyServiceFor === "function")
      service = hostShell.firstPartyServiceFor("omarchy.notifications")
    if (!service && typeof hostShell.ensureService === "function")
      service = hostShell.ensureService("omarchy.notifications")
    if (service) notificationService = service
  }

  function stripMarkup(value) {
    return String(value || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim()
  }

  function moveCursor(delta) {
    if (activeCount === 0) return
    cursor = Math.max(0, Math.min(activeCount - 1, cursor + delta))
    list.positionViewAtIndex(cursor, ListView.Contain)
  }

  function switchTab() {
    activeTab = activeTab === "pending" ? "past" : "pending"
    cursor = 0
  }

  function dismissRow(index) {
    if (!notificationService || index < 0 || index >= activeCount) return
    if (activeTab === "pending") notificationService.dismissPending(index)
    else notificationService.dismissPast(index)
  }

  function activateSelected() {
    dismissRow(cursor)
  }

  function primaryAction() {
    if (!notificationService) return
    if (activeTab === "pending") notificationService.markAllSeen()
    else notificationService.clearPast()
  }

  function toggleDnd() {
    if (notificationService) notificationService.setDoNotDisturb(!notificationService.doNotDisturb)
  }

  onOpenedChanged: if (opened) {
    refreshService()
    activeTab = pendingCount > 0 ? "pending" : "past"
    cursor = 0
  }
  onHostShellChanged: refreshService()
  onActiveCountChanged: if (cursor >= activeCount) cursor = Math.max(0, activeCount - 1)

  Component.onCompleted: refreshService()

  Timer {
    interval: 1000
    running: root.notificationService === null
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshService()
  }

  Connections {
    target: root.notificationService
    ignoreUnknownSignals: true
    function onHistoryOpenRequested() { root.open() }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    active: root.pendingCount > 0 && !root.dnd
    dimmed: root.notificationService === null || root.dnd
    tooltipText: root.notificationService === null ? "Notifications unavailable"
      : (root.dnd ? "Do Not Disturb" : (root.pendingCount > 0 ? root.pendingCount + " pending" : "No notifications"))
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.toggleDnd()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: pop
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: pop.fittedContentWidth(Style.space(380))
    contentHeight: pop.fittedContentHeight(content.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.switchTab()
        else root.moveCursor(dy)
      }
      onActivateRequested: root.activateSelected()

      Column {
        id: content
        width: parent.width
        spacing: Style.space(8)

        Item {
          width: parent.width
          height: Style.space(22)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "notifications"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 2
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.dnd ? "dnd on" : "dnd off"
            color: root.dnd ? Color.accent : Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 2

            MouseArea {
              anchors.fill: parent
              anchors.margins: -Style.space(6)
              enabled: root.notificationService !== null
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.toggleDnd()
            }
          }
        }

        Row {
          width: parent.width
          height: Style.space(28)
          spacing: Style.space(6)

          Repeater {
            model: [
              { key: "pending", label: "pending", count: root.pendingCount },
              { key: "past", label: "recent", count: root.pastCount }
            ]

            BorderSurface {
              required property var modelData
              readonly property bool selected: root.activeTab === modelData.key
              width: (parent.width - parent.spacing) / 2
              height: parent.height
              color: selected ? Style.selectedFillFor(Color.popups.text, Color.accent) : "transparent"
              borderSpec: Border.controlSpec(selected ? "focus" : "normal", Color.popups.text, Color.accent)
              radius: Math.min(Style.cornerRadius, Style.space(6))

              Text {
                anchors.centerIn: parent
                text: modelData.label + (modelData.count > 0 ? " " + modelData.count : "")
                color: parent.selected ? Color.popups.text : Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.activeTab = modelData.key
                  root.cursor = 0
                }
              }
            }
          }
        }

        Rectangle { width: parent.width; height: 1; color: Color.popups.text; opacity: 0.08 }

        Item {
          width: parent.width
          height: root.activeCount > 0 ? Style.space(22) : 0
          visible: root.activeCount > 0

          Text {
            id: actionLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.activeTab === "pending" ? "mark all seen" : "clear recent"
            color: actionMouse.containsMouse ? Color.popups.text : Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption

            MouseArea {
              id: actionMouse
              anchors.fill: parent
              anchors.margins: -Style.space(6)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.primaryAction()
            }
          }
        }

        ListView {
          id: list
          width: parent.width
          height: visible ? Math.min(contentHeight, Style.space(330)) : 0
          visible: root.activeCount > 0
          clip: true
          interactive: contentHeight > height
          boundsBehavior: Flickable.StopAtBounds
          spacing: Style.space(6)
          model: root.activeModel

          delegate: Item {
            id: row
            required property int index
            required property string app
            required property string summary
            required property string body
            required property int urgency

            readonly property bool selected: index === root.cursor
            readonly property string cleanBody: root.stripMarkup(body)

            width: list.width
            height: Math.max(Style.space(44), textColumn.implicitHeight + Style.space(14))

            Rectangle {
              anchors.fill: parent
              radius: Math.min(Style.cornerRadius, Style.space(5))
              color: Color.popups.text
              opacity: row.selected ? 0.08 : 0
              Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Text {
              id: urgencyGlyph
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(18)
              text: row.urgency === 2 ? "!" : "\u{f009c}"
              color: row.urgency === 2 ? Color.urgent : Color.muted
              horizontalAlignment: Text.AlignHCenter
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            Column {
              id: textColumn
              anchors.left: urgencyGlyph.right
              anchors.leftMargin: Style.space(8)
              anchors.right: closeGlyph.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)

              Text {
                width: parent.width
                text: row.summary || row.app || "Notification"
                color: Color.popups.text
                elide: Text.ElideRight
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              Text {
                width: parent.width
                visible: row.cleanBody !== ""
                text: row.cleanBody
                color: Color.muted
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            Text {
              id: closeGlyph
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: "x"
              color: closeMouse.containsMouse ? Color.popups.text : Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption

              MouseArea {
                id: closeMouse
                anchors.fill: parent
                anchors.margins: -Style.space(8)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dismissRow(row.index)
              }
            }

            HoverHandler {
              onHoveredChanged: if (hovered) root.cursor = row.index
            }
          }
        }

        Text {
          visible: root.notificationService === null || root.activeCount === 0
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.notificationService === null ? "notification service unavailable"
            : (root.activeTab === "pending" ? "nothing pending" : "nothing recent")
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          topPadding: Style.space(18)
          bottomPadding: Style.space(18)
        }

        Text {
          width: parent.width
          text: "enter dismisses    left/right tabs    right click dnd"
          color: Color.muted
          elide: Text.ElideRight
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
