import QtQuick
import qs.Commons
import qs.Commons as Commons

// The scrolling history and the empty state that stands in for it. Whole rows
// only: a list that ends mid-row reads as a bug.
Column {
  id: root

  required property var tr
  property var rows: []
  property real lastSeen: 0

  readonly property real rowHeight: Style.space(68)
  readonly property int maxVisibleRows: 6
  readonly property int shownCount: Math.min(root.rows.length, 100)

  signal activated(var entry)
  signal removeRequested(string key)

  width: parent ? parent.width : 0
  spacing: Style.space(6)

  // Empty state
  Column {
    width: parent.width
    visible: root.rows.length === 0
    spacing: Style.space(6)

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "\uf0f3"
      color: Util.alpha(Commons.Color.popups.text, 0.25)
      font.family: Style.font.family
      font.pixelSize: Style.space(28)
      textFormat: Text.PlainText
    }
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.tr.t("panel.empty")
      color: Util.alpha(Commons.Color.popups.text, 0.6)
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
    }
  }

  ListView {
    id: list
    width: parent.width
    height: Math.min(root.shownCount, root.maxVisibleRows) * (root.rowHeight + Style.space(2)) - Style.space(2)
    visible: root.rows.length > 0
    clip: true
    model: root.shownCount
    spacing: Style.space(2)
    boundsBehavior: Flickable.StopAtBounds

    delegate: NotificationRow {
      required property int index

      width: list.width
      rowHeight: root.rowHeight
      tr: root.tr
      row: root.rows[index] || ({})
      isUnread: Number(row.ts || 0) > root.lastSeen

      onActivated: root.activated(row)
      onRemoveRequested: root.removeRequested(String(row.key || ""))
    }
  }
}
