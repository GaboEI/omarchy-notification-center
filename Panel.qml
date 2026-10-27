import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons as Commons
import qs.Ui

import "History.js" as History

// gabodev.notification-center panel: the notification history Omarchy keeps,
// which its own UI only shows as transient toasts.
//
// This file owns the data and the gestures: the live service and its fallback
// file, the local view state and its persistence, navigation, and what each
// action does. The card itself is composed from PanelSurface, HistoryHeader,
// HistoryList, NotificationRow and PanelFooter, which draw what they are told.
//
// Anchored under the bar and centred, the way a dropdown reads, instead of
// covering the middle of the screen. Rows come from the first-party
// notifications service (`historyEntries`, newest first), filtered by what
// this panel hides: `clearedAt` drops everything older than the last clear,
// `hidden` drops single entries.
Item {
  id: root

  property bool opened: false
  property var shell: null
  property var manifest: null

  readonly property string pluginId: (manifest && manifest.id) || "gabodev.notification-center"
  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/gabodev.notification-center/config.json"
  readonly property string historyPath: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/history.json"

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  Navigator {
    id: navigator
  }
  readonly property var notifService: (root.shell && root.shell.firstPartyServiceFor)
    ? root.shell.firstPartyServiceFor("omarchy.notifications")
    : null

  // Rows from the live service, else the last successful read of its state
  // file. A native atomic rewrite can briefly fail to parse; never turn that
  // race into an empty panel.
  property var fallbackRows: []
  readonly property var allEntries: {
    var service = root.notifService
    if (service && service.historyLoaded)
      return Array.isArray(service.historyEntries) ? service.historyEntries : []
    return root.fallbackRows;
  }

  // Local view state, persisted.
  property double lastSeen: 0
  property double clearedAt: 0
  property var hidden: ({})
  property bool configReady: false
  property bool historyLoadFailed: false
  property bool configDirty: false
  property var pendingStateActions: []

  property string navigationFeedback: ""
  readonly property var entries: History.visibleRows(root.allEntries, root.historyState())

  readonly property int unread: History.unreadCount(root.allEntries, root.historyState())

  function historyState() {
    return { version: 2, lastSeen: root.lastSeen, clearedAt: root.clearedAt, hidden: root.hidden };
  }

  function applyHistoryState(state) {
    root.lastSeen = Number(state.lastSeen) || 0;
    root.clearedAt = Number(state.clearedAt) || 0;
    root.hidden = state.hidden || ({});
  }

  function mutateHistory(change) {
    if (!root.configReady) {
      root.pendingStateActions = root.pendingStateActions.concat([change]);
      return;
    }
    root.applyHistoryState(change(root.historyState()));
    root.configDirty = true;
    configSaveTimer.restart();
  }

  function finishConfigLoad(text) {
    if (root.configReady)
      return;
    var state = History.parseConfig(text, Date.now() / 1000);
    root.applyHistoryState(state);
    root.configReady = true;
    // Canonical output upgrades v1's hidden array to the bounded v2 key map.
    root.configDirty = History.serialiseConfig(state) !== String(text || "");
    var pending = root.pendingStateActions;
    root.pendingStateActions = [];
    for (var i = 0; i < pending.length; i++)
      root.mutateHistory(pending[i]);
    if (root.configDirty && !configSaveTimer.running)
      configSaveTimer.start();
  }

  function flushConfig() {
    if (!root.configReady || !root.configDirty)
      return;
    root.configDirty = false;
    configFile.setText(History.serialiseConfig(root.historyState()));
  }

  // Screen x the panel should hang from, passed by the bar widget that opens
  // it. -1 means no anchor (keybind, menu) and keeps the centred placement.
  property real anchorX: -1

  function open(payloadJson) {
    var x = -1
    try { x = Number(JSON.parse(payloadJson || "{}").anchorX) } catch (e) { x = -1 }
    root.anchorX = isFinite(x) && x > 0 ? x : -1
    root.opened = true;
    Qt.callLater(function () {
      if (root.opened)
        surface.grabFocus();
    });
  }

  function close() {
    root.opened = false;
  }

  function dismiss() {
    if (root.shell && root.shell.hide)
      root.shell.hide(root.pluginId);
    else
      root.close();
  }

  // Every footer action also closes the panel: the point of pressing one is to
  // be done with the list, not to look at the result.
  function markRead() {
    var rows = root.entries.slice();
    var at = Date.now() / 1000;
    root.mutateHistory(function(state) { return History.markRead(state, rows, at); });
    root.dismiss();
  }

  function hideEntry(key) {
    var k = String(key || "");
    if (k === "")
      return;
    var at = Date.now() / 1000;
    root.mutateHistory(function(state) { return History.hide(state, k, at); });
  }

  function closeAll() {
    var rows = root.entries.slice();
    var at = Date.now() / 1000;
    root.mutateHistory(function(state) { return History.clear(state, rows, at); });
    dismissAllProc.running = false;
    dismissAllProc.running = true;
    root.dismiss();
  }

  function clearHistory() {
    var rows = root.entries.slice();
    var at = Date.now() / 1000;
    root.mutateHistory(function(state) { return History.clear(state, rows, at); });
    root.dismiss();
  }

  // Persisted history has no live notification action or message deep link. A
  // row closes only after Navigator accepts its limited safe target.
  function showNavigationFeedback() {
    root.navigationFeedback = strings.t("panel.navigationUnavailable");
    navigationFeedbackTimer.restart();
  }

  function activateEntry(row) {
    var action = navigator.resolve(row);
    if (!action.ok) {
      root.showNavigationFeedback();
      return;
    }

    if (action.kind === "desktop-candidate") {
      // Navigator maps this ID from a fixed alias and confirms its desktop
      // entry exists; never derive a launcher command from notification data.
      var desktopId = String(action.desktopId || "");
      if (!/^(org\.telegram\.desktop|WhatsApp|discord)$/.test(desktopId)) {
        root.showNavigationFeedback();
        return;
      }
      desktopLaunchProc.command = ["uwsm-app", "--", "gtk-launch",
                                   /\.desktop$/.test(desktopId) ? desktopId : desktopId + ".desktop"];
      desktopLaunchProc.running = false;
      desktopLaunchProc.running = true;
      return;
    }

    var result = navigator.perform(action);
    if (result.ok)
      root.dismiss();
    else
      root.showNavigationFeedback();
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.finishConfigLoad(text())
    onLoadFailed: root.finishConfigLoad("")
  }

  Timer {
    id: configSaveTimer
    interval: 180
    onTriggered: root.flushConfig()
  }

  Timer {
    id: navigationFeedbackTimer
    interval: 2100
    onTriggered: root.navigationFeedback = ""
  }

  FileView {
    id: historyFile
    path: root.historyPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var data = JSON.parse(historyFile.text());
        if (Array.isArray(data)) {
          root.fallbackRows = data;
          root.historyLoadFailed = false;
        } else {
          root.historyLoadFailed = true;
        }
      } catch (error) {
        root.historyLoadFailed = true;
      }
    }
    onLoadFailed: root.historyLoadFailed = true
  }

  Component.onDestruction: {
    configSaveTimer.stop();
    root.flushConfig();
  }

  Process {
    id: dismissAllProc
    command: ["omarchy-shell", "notifications", "dismissAll"]
  }

  Process {
    id: desktopLaunchProc
    command: ["true"]
    onExited: function(exitCode) {
      if (exitCode === 0)
        root.dismiss();
      else
        root.showNavigationFeedback();
    }
  }

  OverlayWindow {
    id: win
    shown: root.opened
    WlrLayershell.namespace: "gabodev-notification-center"

    PanelSurface {
      id: surface
      anchors.fill: parent
      opened: root.opened
      unread: root.unread
      anchorX: root.anchorX
      onDismissed: root.dismiss()
      content: [
        HistoryHeader {
          tr: strings
          unread: root.unread
          total: root.entries.length
        },
        HistoryList {
          tr: strings
          rows: root.entries
          lastSeen: root.lastSeen
          onActivated: root.activateEntry(entry)
          onRemoveRequested: root.hideEntry(key)
        },
        PanelFooter {
          tr: strings
          feedback: root.navigationFeedback
          showRule: root.entries.length > 0
          onMarkReadRequested: root.markRead()
          onCloseAllRequested: root.closeAll()
          onClearRequested: root.clearHistory()
          onDismissRequested: root.dismiss()
        }
      ]
    }
  }
}
