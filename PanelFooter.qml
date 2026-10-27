import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The bottom of the panel: temporary feedback, the rule before the actions, the
// three list actions on the left and Close pinned to the right edge. Every
// action is reported upwards; the panel decides what it does.
Column {
  id: root

  required property var tr
  property string feedback: ""
  property bool showRule: false

  signal markReadRequested()
  signal closeAllRequested()
  signal clearRequested()
  signal dismissRequested()

  width: parent ? parent.width : 0
  spacing: Style.spacing.panelGap

  Text {
    width: parent.width
    visible: root.feedback !== ""
    text: root.feedback
    color: Util.alpha(Commons.Color.popups.text, 0.65)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    textFormat: Text.PlainText
  }

  // Hairline before the actions
  Rectangle {
    width: parent.width
    height: 1
    color: Util.alpha(Commons.Color.popups.text, 0.08)
    visible: root.showRule
  }

  Item {
    width: parent.width
    height: Math.max(actions.implicitHeight, closeBtn.implicitHeight)

    Row {
      id: actions
      spacing: Style.space(8)

      Button {
        text: root.tr.t("panel.markRead")
        onClicked: root.markReadRequested()
        foreground: Commons.Color.popups.text
        background: Commons.Color.popups.background
        accent: Commons.Color.accent
        fontFamily: Style.font.family
      }

      Button {
        text: root.tr.t("panel.closeAll")
        onClicked: root.closeAllRequested()
        foreground: Commons.Color.popups.text
        background: Commons.Color.popups.background
        accent: Commons.Color.accent
        fontFamily: Style.font.family
      }

      Button {
        text: root.tr.t("panel.clear")
        onClicked: root.clearRequested()
        foreground: Commons.Color.popups.text
        background: Commons.Color.popups.background
        accent: Commons.Color.accent
        fontFamily: Style.font.family
      }
    }

    Button {
      id: closeBtn
      anchors.right: parent.right
      text: root.tr.t("panel.close")
      onClicked: root.dismissRequested()
      foreground: Util.alpha(Commons.Color.popups.text, 0.7)
      background: Commons.Color.popups.background
      accent: Commons.Color.accent
      fontFamily: Style.font.family
    }
  }
}
