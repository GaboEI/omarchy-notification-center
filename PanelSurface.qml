import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Card chrome for the notification panel: placement under the bar, the border,
// the unread hairline, and the two ways out of it. The panel hands its parts in
// through `content`, in the order they stack; this file holds no data and no state.
Item {
  id: root

  property bool opened: false
  property int unread: 0
  // Screen x the card centres on: the bar widget that opened it. -1 keeps the
  // old screen-centred placement used by a keybind or menu summon.
  property real anchorX: -1

  readonly property real cardWidth: Style.space(540)
  readonly property real edgeMargin: Style.space(12)

  function cardX(available) {
    var centred = (available - cardWidth) / 2
    if (!(root.anchorX > 0))
      return centred
    var wanted = root.anchorX - cardWidth / 2
    var limit = Math.max(edgeMargin, available - cardWidth - edgeMargin)
    return Math.max(edgeMargin, Math.min(wanted, limit))
  }
  // Ordered by the list the panel passes: each item joins the column in that
  // order, which is what decides the vertical stack.
  property list<Item> content

  signal dismissed()

  function grabFocus() {
    keyCatcher.forceActiveFocus();
  }

  function placeContent() {
    for (var i = 0; i < root.content.length; i++)
      if (root.content[i])
        root.content[i].parent = col;
  }

  onContentChanged: root.placeContent()
  Component.onCompleted: root.placeContent()

  // Click outside the card.
  MouseArea {
    anchors.fill: parent
    onClicked: root.dismissed()
  }

  BorderSurface {
    id: card
    // Hangs from the bar, centred on the screen, so it never covers the
    // middle of what you were reading.
    anchors.top: parent.top
    anchors.topMargin: Style.bar.sizeHorizontal + Style.space(8)
    // Hung from the bell: its centre is the card's centre, pulled in only when
    // that would push the card past a screen edge.
    x: root.cardX(parent.width)
    width: root.cardWidth
    height: Math.min(parent.height - Style.space(96),
                     card.borderTop + Style.spacing.panelPadding + col.implicitHeight + Style.spacing.panelPadding + card.borderBottom)
    color: Commons.Color.popups.background
    radius: Style.cornerRadius
    borderSpec: Border.localOrSurfaceSpec("popups", "border", Commons.Color.popups.border, Commons.Color.popups.border, Math.max(1, Style.space(2)))

    opacity: root.opened ? 1 : 0
    Behavior on opacity {
      NumberAnimation {
        duration: 140
        easing.type: Easing.OutCubic
      }
    }

    // Clicks on the card are not clicks outside it.
    MouseArea {
      anchors.fill: parent
    }

    // A hair of accent along the top edge while something is unread: the
    // one cue that reads at a glance from across the room.
    Rectangle {
      anchors.top: parent.top
      anchors.topMargin: card.borderTop
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.max(0, parent.width - 2 * card.borderLeft)
      height: Style.space(2)
      color: Util.alpha(Commons.Color.accent, root.unread > 0 ? 0.55 : 0)
      Behavior on color {
        ColorAnimation {
          duration: 160
        }
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.dismissed()
    }

    Column {
      id: col
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: card.borderLeft + Style.spacing.panelPadding
      anchors.rightMargin: card.borderRight + Style.spacing.panelPadding
      anchors.topMargin: card.borderTop + Style.spacing.panelPadding
      spacing: Style.spacing.panelGap
    }
  }
}
