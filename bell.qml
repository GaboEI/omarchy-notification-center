import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

import "History.js" as History

// Bar bell: unread count from the history Omarchy keeps, left-click opens this
// plugin's panel, right-click flips Omarchy's own quiet mode. Quiet is read
// from the file the notifications service writes, because a third-party bar
// widget is only handed a capability-scoped service facade.
WidgetButton {
  id: root

  // The bar host fills these on every widget that declares them.
  property string moduleName: "gabodev.notification-center"
  property var settings: ({})

  // Glyph and count sit in one measured grid, so the widget widens with the
  // badge instead of pinning a badge over an already-widened icon slot.
  hasVisualContent: true
  labelVisible: false
  tooltipText: root.tooltip()

  readonly property string quietPath:
    Quickshell.env("HOME") + "/.local/state/omarchy/notifications/quiet.json"
  readonly property string historyPath:
    Quickshell.env("HOME") + "/.local/state/omarchy/notifications/history.json"
  readonly property string configPath:
    Quickshell.env("HOME") + "/.config/omarchy/gabodev.notification-center/config.json"

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  // History: the live service when this build exposes it to a bar widget,
  // else the state file the service writes. The scoped proxy normally has no
  // history entries, so the watched file is the real reader.
  readonly property var notifService:
    (root.bar && root.bar.shell && root.bar.shell.firstPartyServiceFor)
      ? root.bar.shell.firstPartyServiceFor("omarchy.notifications")
      : null

  property var fallbackRows: []
  readonly property var allEntries: {
    var service = root.notifService
    if (service && service.historyLoaded === true && Array.isArray(service.historyEntries))
      return service.historyEntries
    return root.fallbackRows
  }

  // Local view state, persisted by the panel. Parsing and filtering live in
  // History.js so the bell and the panel cannot drift apart.
  property double lastSeen: 0
  property double clearedAt: 0
  property var hidden: ({})

  function historyState() {
    return { version: 2, lastSeen: root.lastSeen, clearedAt: root.clearedAt, hidden: root.hidden }
  }

  readonly property int unread: History.unreadCount(root.allEntries, root.historyState())
  readonly property string badge:
    root.unread > 99 ? "99+" : (root.unread > 0 ? String(root.unread) : "")

  // Omarchy's quiet mode, mirrored from its own state file. A missing or
  // malformed file means DND is off, which is also what the service assumes.
  property bool dnd: false

  function applyQuiet(raw) {
    var text = String(raw || "")
    if (text.length > 4096 || !text.trim()) {
      root.dnd = false
      return
    }
    try {
      let value = JSON.parse(text)
      root.dnd = !!(value && typeof value === "object" && value.dnd === true)
    } catch (error) {
      root.dnd = false
    }
  }

  function applyConfig(raw) {
    var state = History.parseConfig(raw, Date.now() / 1000)
    root.lastSeen = state.lastSeen
    root.clearedAt = state.clearedAt
    root.hidden = state.hidden
  }

  // An atomic rewrite can land unreadable for a moment; keep the last good
  // rows rather than flashing the badge to zero.
  function applyHistory(raw) {
    var text = String(raw || "")
    if (!text.trim())
      return
    let data = null
    try {
      data = JSON.parse(text)
    } catch (error) {
      return
    }
    if (Array.isArray(data))
      root.fallbackRows = data
  }

  function tooltip() {
    if (root.dnd)
      return root.unread > 0
        ? strings.t("bell.silencedUnread").arg(Commons.I18n.formatNumber(root.unread))
        : strings.t("bell.silenced")
    return root.unread > 0
      ? strings.t("bell.unread").arg(Commons.I18n.formatNumber(root.unread))
      : strings.t("bell.history")
  }

  // The panel hangs from this widget, so it is told where the widget sits on
  // screen right before opening: move the bell and the panel moves with it.
  // The panel is an overlay window on one screen, so it wants coordinates
  // local to that screen. mapToGlobal() answers in virtual-desktop space, which
  // lands on the wrong monitor whenever the bar is not on the first one; the
  // window mapping is the one that matches the overlay.
  function anchorPayload() {
    try {
      var local = root.mapToItem(null, root.width / 2, 0)
      var x = Math.round(local.x)
      return x >= 0 ? JSON.stringify({ "anchorX": x }) : "{}"
    } catch (e) {
      return "{}"
    }
  }

  function openPanel() {
    var payload = root.anchorPayload()
    if (root.bar && root.bar.shell && root.bar.shell.summon) {
      root.bar.shell.summon("gabodev.notification-center", payload)
      return
    }
    // Fallback for a host that has not exposed the shell on the bar API yet.
    Quickshell.execDetached(["omarchy-shell", "shell", "summon", "gabodev.notification-center", payload])
  }

  // Omarchy's IPC takes the value rather than a toggle, so two quick presses
  // both aim at the state the bar last saw instead of flipping twice.
  function setDnd(on) {
    Quickshell.execDetached(["omarchy-shell", "notifications", "setDnd", on ? "true" : "false"])
  }

  onPressed: function(button) {
    if (button === Qt.LeftButton)
      root.openPanel()
    else if (button === Qt.RightButton)
      root.setDnd(!root.dnd)
  }

  implicitWidth: root.vertical
    ? root.barSize
    : Math.max(Style.bar.statusSlot, content.implicitWidth + Style.space(4))
  implicitHeight: root.vertical
    ? Math.max(Style.bar.statusSlot, content.implicitHeight + Style.space(4))
    : root.barSize

  Grid {
    id: content
    // Beside the glyph on a horizontal bar, under it on a vertical one, where
    // the slot is only a bar-width wide. Without a badge the grid is a single
    // cell, so the hidden count leaves no trailing spacing behind.
    columns: root.badge !== "" && !root.vertical ? 2 : 1
    columnSpacing: Style.space(2)
    rowSpacing: Style.space(1)
    anchors.centerIn: parent
    scale: root.pressScale

    OpticalGlyph {
      id: bellGlyph
      width: Style.bar.iconCanvas
      height: Style.bar.iconCanvas
      // Native notifications' bell, and the crossed bell its DND indicator
      // uses, both from the theme's Nerd Font.
      text: root.dnd ? "\uf1f6" : "\uf0f3"
      fontFamily: root.fontFamily
      fontSize: Style.bar.iconFont
      paintedSize: Style.bar.iconSize
      color: root.dnd ? Commons.Color.urgent : root.foreground
    }

    Text {
      id: badgeLabel
      visible: root.badge !== ""
      text: root.badge
      textFormat: Text.PlainText
      color: Commons.Color.accent
      height: bellGlyph.height
      verticalAlignment: Text.AlignVCenter
      renderType: Text.NativeRendering
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  FileView {
    id: quietFile
    path: root.quietPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyQuiet(text())
    onLoadFailed: root.applyQuiet("")
  }

  FileView {
    id: historyFile
    path: root.historyPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyHistory(historyFile.text())
    onLoadFailed: root.applyHistory("")
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyConfig(configFile.text())
    onLoadFailed: root.applyConfig("")
  }
}
