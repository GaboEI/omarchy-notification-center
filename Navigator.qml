// Import QtQuick for QtObject and Qt.openUrlExternally, Quickshell for
// DesktopEntries, Quickshell.Hyprland for toplevels/dispatch, and qs.Commons
// for Util.execArgv. This object has no Component.onCompleted work: a panel
// must explicitly resolve() and perform() a row after a user gesture.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons

QtObject {
  id: root

  readonly property int maxArgvItems: 32
  readonly property int maxArgvItemChars: 2048
  readonly property int maxStoredJsonChars: 32768
  readonly property int maxSourceChars: 253
  readonly property var browserClasses: /^(chrome|chromium|firefox|zen|brave|edge|vivaldi|helium)/
  readonly property var browserSuffix: /\s*[-–—|]\s*(google chrome|chromium|mozilla firefox|firefox|zen browser|brave origin|brave|microsoft edge|vivaldi|helium)\s*$/
  readonly property var genericLabels: ({ www: 1, app: 1, web: 1, my: 1, m: 1,
                                          mail: 1, com: 1, org: 1, net: 1,
                                          io: 1, co: 1, dev: 1, ai: 1, so: 1,
                                          site: 1, uk: 1 })

  // Only these fixed icon aliases can propose a desktop entry. In particular,
  // notification text, app names, and sources never become launch commands.
  readonly property var desktopAliases: ({
    "org.telegram.desktop": { id: "org.telegram.desktop", label: "Telegram" },
    "telegram": { id: "org.telegram.desktop", label: "Telegram" },
    "telegram-desktop": { id: "org.telegram.desktop", label: "Telegram" },
    "whatsapp": { id: "WhatsApp", label: "WhatsApp" },
    "whatsapp-desktop": { id: "WhatsApp", label: "WhatsApp" },
    "whatsapp-for-linux": { id: "WhatsApp", label: "WhatsApp" },
    "com.github.tchx84.whatsapp": { id: "WhatsApp", label: "WhatsApp" },
    "discord": { id: "discord", label: "Discord" },
    "discord-canary": { id: "discord", label: "Discord" },
    "discord-ptb": { id: "discord", label: "Discord" },
    "com.discordapp.discord": { id: "discord", label: "Discord" }
  })

  function unavailable(reason) {
    return { ok: false, kind: "unavailable", label: "Unavailable", reason: String(reason || "No safe target is available.") }
  }

  function success(kind, label, extra) {
    var out = { ok: true, kind: kind, label: String(label || "Open"), reason: "" }
    if (extra) for (var key in extra) out[key] = extra[key]
    return out
  }

  function hasControlChars(value) {
    return /[\x00-\x1f\x7f-\x9f]/.test(value)
  }

  function validArgv(argv) {
    if (!Array.isArray(argv) || argv.length === 0 || argv.length > maxArgvItems) return null
    for (var i = 0; i < argv.length; i++) {
      if (typeof argv[i] !== "string" || argv[i].length > maxArgvItemChars || hasControlChars(argv[i])) return null
    }
    if (!argv[0] || argv[0].charAt(0) === "-") return null
    return argv
  }

  // Stored rows contain JSON strings. Arrays and shell-like strings are not an
  // alternate input format; all argv remains positional for Util.execArgv.
  function parseStoredArgv(value) {
    if (typeof value !== "string" || !value || value.length > maxStoredJsonChars) return null
    try { return validArgv(JSON.parse(value)) } catch (error) { return null }
  }

  function parseFirstStoredAction(value) {
    if (typeof value !== "string" || !value || value.length > maxStoredJsonChars) return null
    var actions
    try { actions = JSON.parse(value) } catch (error) { return null }
    if (!Array.isArray(actions) || actions.length === 0 || actions.length > 3) return null
    var first = actions[0]
    if (!first || typeof first !== "object" || Array.isArray(first) || typeof first.label !== "string") return null
    if (!first.label.trim() || first.label.length > 256 || hasControlChars(first.label)) return null
    var argv = validArgv(first.argv)
    return argv ? { label: first.label, argv: argv } : null
  }

  function safeHostname(value) {
    if (typeof value !== "string" || !value || value.length > maxSourceChars || hasControlChars(value)) return ""
    var host = value.toLowerCase().replace(/\.$/, "")
    if (!/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$/.test(host)) return ""
    if (/^(?:0x[0-9a-f]*|[0-9]+)$/i.test(host.split(".").pop())) return ""
    return host
  }

  function rowIsRedacted(row) {
    return String(row.summary || "") === "Verification notification"
      && (String(row.body || "") === "[redacted]" || String(row.bodyLine || "") === "[redacted]")
  }

  function openWindows() {
    var values = Hyprland.toplevels ? Hyprland.toplevels.values : []
    var out = []
    for (var i = 0; i < values.length; i++) {
      var ipc = values[i].lastIpcObject || {}
      var address = String(ipc.address || "")
      if (!/^0x[0-9a-f]+$/i.test(address)) continue
      out.push({
        wmClass: String(ipc["class"] || ""),
        title: String(ipc.title || ""),
        address: address,
        pid: Number(ipc.pid || 0),
        focusOrder: Number(ipc.focusHistoryID !== undefined ? ipc.focusHistoryID : 9999)
      })
    }
    return out
  }

  function mostRecent(candidates) {
    if (!candidates.length) return null
    var best = candidates[0]
    for (var i = 1; i < candidates.length; i++)
      if (candidates[i].focusOrder < best.focusOrder) best = candidates[i]
    return best
  }

  function windowForPid(pid, windows) {
    var wanted = Number(pid || 0)
    if (!wanted) return null
    for (var i = 0; i < windows.length; i++) if (windows[i].pid === wanted) return windows[i]
    return null
  }

  function iconClass(row) {
    var icon = String(row.appIcon || "")
    return /^[A-Za-z0-9_.-]{1,256}$/.test(icon) ? icon.toLowerCase() : ""
  }

  function windowForClass(row, windows) {
    var icon = iconClass(row)
    var i
    if (icon) {
      var exact = []
      for (i = 0; i < windows.length; i++)
        if (windows[i].wmClass.toLowerCase() === icon) exact.push(windows[i])
      if (exact.length) return mostRecent(exact)
    }

    var source = String(row.source || "")
    var host = safeHostname(source)
    if (host) {
      var hostClass = []
      for (i = 0; i < windows.length; i++)
        if (windows[i].wmClass.toLowerCase().indexOf(host) >= 0) hostClass.push(windows[i])
      if (hostClass.length) return mostRecent(hostClass)
      return browserWindowForHost(host, windows)
    }

    var slug = source.toLowerCase().replace(/[^a-z0-9]+/g, "")
    if (slug.length < 4) return null
    var slugClass = []
    for (i = 0; i < windows.length; i++) {
      var wmClass = windows[i].wmClass.toLowerCase()
      if (wmClass === slug) { slugClass.push(windows[i]); continue }
      if (wmClass.indexOf("chrome-") !== 0) continue
      var labels = wmClass.substring(7).split("__")[0].split(".")
      for (var j = 0; j < labels.length; j++)
        if (labels[j] === slug) { slugClass.push(windows[i]); break }
    }
    return mostRecent(slugClass)
  }

  function brandsOf(host) {
    var labels = host.toLowerCase().split(".")
    var out = []
    for (var i = 0; i < labels.length; i++) {
      if (labels[i].length >= 4 && !genericLabels[labels[i]]) { out.push(labels[i]); break }
    }
    var registered = labels.length >= 2 ? labels[labels.length - 2] : ""
    if (registered.length >= 4 && !genericLabels[registered] && out.indexOf(registered) < 0) out.push(registered)
    return out
  }

  function wordIn(text, word) {
    var at = text.indexOf(word)
    while (at >= 0) {
      var before = at === 0 ? "" : text.charAt(at - 1)
      var after = text.charAt(at + word.length)
      if (!/[a-z0-9]/.test(before) && !/[a-z0-9]/.test(after)) return true
      at = text.indexOf(word, at + 1)
    }
    return false
  }

  // This selects only a browser *window* from its class/title. Persisted history
  // has no tab identity, so it cannot select or claim to restore a browser tab.
  function browserWindowForHost(host, windows) {
    var brands = brandsOf(host)
    for (var b = 0; b < brands.length; b++) {
      var matches = []
      for (var i = 0; i < windows.length; i++) {
        if (!browserClasses.test(windows[i].wmClass.toLowerCase())) continue
        var title = windows[i].title.toLowerCase().replace(browserSuffix, "")
        if (wordIn(title, brands[b])) matches.push(windows[i])
      }
      if (matches.length) return mostRecent(matches)
    }
    return null
  }

  // A desktop entry is only usable when the file really exists: byId() is the
  // shell's own lookup, and it accepts both the bare id and "<id>.desktop".
  // `launchId` is the bare basename gtk-launch takes; `desktopId` is what the
  // lookup confirmed. Nothing is inferred from notification text.
  function desktopCandidate(row) {
    var alias = desktopAliases[iconClass(row)]
    if (!alias) return null
    var forms = [alias.id, alias.id + ".desktop"]
    for (var i = 0; i < forms.length; i++) {
      try {
        if (DesktopEntries.byId(forms[i]))
          return { id: alias.id, launchId: alias.id, label: alias.label }
      } catch (error) {
      }
    }
    return null
  }

  // History has deliberately lost the live notification QObject. It cannot
  // invoke libnotify's sender-defined "default" action; only persisted argv
  // values are executable, and source navigation uses the limited fallbacks.
  function resolve(row) {
    if (!row || typeof row !== "object" || Array.isArray(row)) return unavailable("The notification row is invalid.")
    if (rowIsRedacted(row)) return unavailable("Redacted notifications cannot be opened.")

    var argv = parseStoredArgv(row.execArgv)
    if (argv) return success("exec", "Open notification", { argv: argv })

    var action = parseFirstStoredAction(row.execActions)
    if (action) return success("exec-action", action.label, { argv: action.argv })

    var windows = openWindows()
    var pidWindow = windowForPid(row.senderPid, windows)
    if (pidWindow) return success("pid-window", "Focus notification source", { address: pidWindow.address })

    var classWindow = windowForClass(row, windows)
    if (classWindow) return success("class-window", "Focus notification source", { address: classWindow.address })

    var host = safeHostname(String(row.source || ""))
    if (host) return success("host-url", "Open " + host, { url: "https://" + host + "/" })

    var desktop = desktopCandidate(row)
    if (desktop) return success("desktop-candidate", "Open " + desktop.label, { desktopId: desktop.id, launchId: desktop.launchId, desktopName: desktop.label })

    return unavailable("No safe target is available for this notification.")
  }

  function focusAddress(address) {
    var value = String(address || "")
    if (!/^0x[0-9a-f]+$/i.test(value)) return unavailable("The window target is invalid.")
    var windows = openWindows()
    var found = false
    for (var i = 0; i < windows.length; i++) if (windows[i].address === value) { found = true; break }
    if (!found) return unavailable("The notification source window is no longer open.")
    Hyprland.dispatch('hl.dsp.focus({window = hl.get_window("address:' + value + '")})')
    return success("focused", "Focused notification source")
  }

  // Call only in a click/key handler. Desktop candidates intentionally return
  // data from resolve(); the panel may pass that fixed, validated ID to its
  // trusted app launcher rather than this helper launching an arbitrary app.
  function perform(action) {
    if (!action || action.ok !== true) return unavailable(action && action.reason ? action.reason : "No safe action is available.")
    if (action.kind === "exec" || action.kind === "exec-action") {
      var argv = validArgv(action.argv)
      if (!argv) return unavailable("The stored command is invalid.")
      try { Util.execArgv(argv) } catch (error) { return unavailable("The stored command could not be started.") }
      return success("executed", String(action.label || "Opened notification"))
    }
    if (action.kind === "pid-window" || action.kind === "class-window") return focusAddress(action.address)
    if (action.kind === "host-url") {
      var host = safeHostname(String(action.url || "").replace(/^https:\/\//i, "").replace(/\/$/, ""))
      if (!host || String(action.url) !== "https://" + host + "/") return unavailable("The website target is invalid.")
      return Qt.openUrlExternally(String(action.url))
        ? success("opened-url", String(action.label || "Opened website"))
        : unavailable("The website could not be opened.")
    }
    if (action.kind === "desktop-candidate")
      return unavailable("A trusted panel launcher must handle this desktop entry.")
    return unavailable("The requested action is not supported.")
  }
}
