import QtQuick
import Quickshell.Io

// Optional precision filter for the browser route.
//
// Chromium's MPRIS metadata cannot distinguish YouTube Music from any other
// site — measured on a live session, both leave `album` empty. The window
// title can: YouTube Music renders "<track> | YouTube Music" while a plain
// video renders "<title> - YouTube".
//
// It is a trade, not a free win. A browser window reports the title of its
// *active* tab, so switching that window to another tab while music keeps
// playing in the background makes the match disappear. That is why this is
// off by default: a widget that goes blank while music plays is worse than
// one that occasionally adopts the wrong media.
Item {
  id: root

  property bool enabled: false
  readonly property bool matched: _matched

  property bool _matched: false

  onEnabledChanged: if (!enabled) _matched = false

  Timer {
    interval: 3000
    running: root.enabled
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!probe.running) probe.running = true
  }

  Process {
    id: probe
    command: ["hyprctl", "clients", "-j"]

    stdout: StdioCollector {
      onStreamFinished: root._matched = root.scan(text)
    }
  }

  // "YouTube Music" must end the page title, optionally followed by the
  // browser's own suffix. A plain substring test is not enough: a GitHub page
  // *about* YouTube Music matched during testing, which would have made the
  // filter adopt unrelated media.
  function isYouTubeMusicTitle(title) {
    return /youtube music( [-\u2014|].*)?$/i.test(String(title || ""))
  }

  function scan(payload) {
    try {
      var clients = JSON.parse(payload)
      for (var i = 0; i < clients.length; i++) {
        if (isYouTubeMusicTitle(clients[i].title)) return true
      }
    } catch (error) {
      // hyprctl missing or not Hyprland: fail open rather than blanking the
      // widget over a filter the user only asked to narrow things with.
      return true
    }
    return false
  }
}
