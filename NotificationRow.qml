import QtQuick
import qs.Commons
import qs.Commons as Commons

// One notification: hover and unread fills, the unread dot, the app glyph, the
// metadata and text, the relative time, and the per-row close. It reads the row
// it is given and reports gestures; it never acts on one itself.
Rectangle {
  id: rowItem

  required property var tr
  property var row: ({})
  property bool isUnread: false
  property real rowHeight: Style.space(68)

  signal activated()
  signal removeRequested()

  // Relative time, in the reader's language.
  function ago(ts) {
    var t = Number(ts || 0);
    if (t <= 0)
      return "";
    var d = Math.max(0, Date.now() / 1000 - t);
    if (d < 60)
      return root.tr.t("time.now");
    if (d < 3600)
      return root.tr.t("time.minutes").arg(Math.trunc(d / 60));
    if (d < 86400)
      return root.tr.t("time.hours").arg(Math.trunc(d / 3600));
    return root.tr.t("time.days").arg(Math.trunc(d / 86400));
  }

  width: parent ? parent.width : 0
  height: rowHeight
  radius: Style.space(3)
  color: rowHover.hovered
         ? Util.alpha(Commons.Color.popups.text, 0.06)
         : (rowItem.isUnread ? Util.alpha(Commons.Color.accent, 0.07) : "transparent")

  Behavior on color {
    ColorAnimation {
      duration: 90
    }
  }

  HoverHandler {
    id: rowHover
  }

  // Resolving the target is the panel's job: this only reports the gesture.
  MouseArea {
    anchors.fill: parent
    onClicked: rowItem.activated()
  }

  // Unread dot
  Rectangle {
    id: dot
    anchors.left: parent.left
    anchors.leftMargin: Style.space(10)
    anchors.top: parent.top
    anchors.topMargin: Style.space(14)
    width: Style.space(5)
    height: width
    radius: width / 2
    color: Commons.Color.accent
    visible: rowItem.isUnread
  }

  // App glyph, when the notification carries one.
  Text {
    id: glyph
    anchors.left: dot.right
    anchors.leftMargin: Style.space(8)
    anchors.verticalCenter: dot.verticalCenter
    text: String(rowItem.row.glyph || "\uf0f3")
    color: Util.alpha(Commons.Color.popups.text, 0.55)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    textFormat: Text.PlainText
  }

  Column {
    id: rowCol
    anchors.left: glyph.right
    anchors.leftMargin: Style.space(8)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(28)
    anchors.top: parent.top
    anchors.topMargin: Style.space(9)
    spacing: Style.space(2)

    Item {
      width: parent.width
      height: appText.implicitHeight

      Text {
        id: appText
        anchors.left: parent.left
        anchors.right: timeText.left
        anchors.rightMargin: Style.space(8)
        text: String(rowItem.row.app || rowItem.row.source || "")
        color: Util.alpha(Commons.Color.popups.text, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      Text {
        id: timeText
        anchors.right: parent.right
        text: rowItem.ago(rowItem.row.ts)
        color: Util.alpha(Commons.Color.popups.text, 0.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        textFormat: Text.PlainText
      }
    }

    Text {
      width: parent.width
      text: String(rowItem.row.summary || "")
      color: Commons.Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      wrapMode: Text.WordWrap
      maximumLineCount: 1
      elide: Text.ElideRight
      textFormat: Text.PlainText
    }

    Text {
      width: parent.width
      visible: String(rowItem.row.body || "") !== ""
      text: String(rowItem.row.body || "")
      color: Util.alpha(Commons.Color.popups.text, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
      maximumLineCount: 1
      elide: Text.ElideRight
      textFormat: Text.PlainText
    }
  }

  // Per-row close
  Text {
    anchors.right: parent.right
    anchors.rightMargin: Style.space(9)
    anchors.top: parent.top
    anchors.topMargin: Style.space(7)
    text: "×"
    color: rowCloseHover.hovered
           ? Commons.Color.popups.text
           : Util.alpha(Commons.Color.popups.text, 0.3)
    font.family: Style.font.family
    font.pixelSize: Style.font.title
    textFormat: Text.PlainText

    HoverHandler {
      id: rowCloseHover
    }

    MouseArea {
      anchors.fill: parent
      anchors.margins: -Style.space(7)
      onClicked: rowItem.removeRequested()
    }
  }
}
