import QtQuick
import qs.Commons
import qs.Commons as Commons

// Title on the left, the count as a pill on the right. The panel injects the
// catalog, so this file owns the pill's copy and nothing else.
Item {
  id: root

  required property var tr
  property int unread: 0
  property int total: 0

  width: parent ? parent.width : 0
  height: Math.max(titleLabel.implicitHeight, pill.height)

  Text {
    id: titleLabel
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: root.tr.t("panel.title")
    color: Commons.Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.title
    font.bold: true
    textFormat: Text.PlainText
  }

  Rectangle {
    id: pill
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    visible: root.total > 0
    width: pillLabel.implicitWidth + Style.space(14)
    height: pillLabel.implicitHeight + Style.space(6)
    radius: height / 2
    color: root.unread > 0
           ? Util.alpha(Commons.Color.accent, 0.18)
           : Util.alpha(Commons.Color.popups.text, 0.08)

    Text {
      id: pillLabel
      anchors.centerIn: parent
      text: root.unread > 0
            ? root.tr.t("panel.unread").arg(Commons.I18n.formatNumber(root.unread))
            : root.tr.t("panel.allRead").arg(Commons.I18n.formatNumber(root.total))
      color: root.unread > 0 ? Commons.Color.accent : Util.alpha(Commons.Color.popups.text, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: root.unread > 0
      textFormat: Text.PlainText
    }
  }
}
