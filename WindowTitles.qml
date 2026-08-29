import QtQuick
import Quickshell.Io

// Browser-source detection for the browser route.
//
// Chromium's MPRIS metadata cannot distinguish YouTube Music from any other
// site — measured on a live session, both leave `album` empty. The window
// title can: YouTube Music renders "<track> | YouTube Music" while a plain
// video renders "<title> - YouTube", and other media pages carry their own
// brand in the title.
//
// `matched` is the precision filter used by Strict browser match: only adopt
// a browser session while a window titled *YouTube Music* is open. `brand` is
// a best-effort guess of where the audio actually comes from, shown in the
// popup header.
//
// It is a trade, not a free win. A browser window reports the title of its
// *active* tab, so switching that window to another tab while music keeps
// playing in the background makes the match disappear. That is why the strict
// filter is off by default; the brand label degrades to the player identity
// when the title cannot say.
Item {
  id: root

  property bool enabled: false
  readonly property bool matched: _matched
  // "" (unknown), "YouTube Music", "YouTube", or a browser page brand.
  readonly property string brand: _brand

  property bool _matched: false
  property string _brand: ""

  onEnabledChanged: if (!enabled) {
    _matched = false
    _brand = ""
  }

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
      onStreamFinished: root.scan(text)
    }
  }

  // "YouTube Music" must end the page title, optionally followed by the
  // browser's own suffix. A plain substring test is not enough: a GitHub page
  // *about* YouTube Music matched during testing, which would have made the
  // filter adopt unrelated media.
  function isYouTubeMusicTitle(title) {
    return /youtube music( [-\u2014|].*)?$/i.test(String(title || ""))
  }

  // Plain YouTube renders "<video> - YouTube"; the brand must end the title.
  function isYouTubeTitle(title) {
    return /- youtube$/i.test(String(title || "").trim())
  }

  // A rough "is this a media page at all" test: the title carries a track,
  // video, song, episode or stream marker. Everything else (a settings page,
  // a folder listing) is not the audio source.
  function looksLikeMedia(title) {
    var t = String(title || "")
    if (t.trim() === "") return false
    if (t.indexOf(" - ") === -1 && t.indexOf(" | ") === -1) return false
    return true
  }

  function scan(payload) {
    var matched = false
    var brand = ""
    try {
      var clients = JSON.parse(payload)
      var foundYt = false
      var foundMedia = false
      for (var i = 0; i < clients.length; i++) {
        var title = clients[i].title
        if (isYouTubeMusicTitle(title)) {
          matched = true
          brand = "YouTube Music"
          break
        }
        if (isYouTubeTitle(title)) foundYt = true
        if (looksLikeMedia(title)) foundMedia = true
      }
      if (!matched && foundYt) brand = "YouTube"
      else if (!matched && foundMedia && brand === "") brand = ""
      _matched = matched
      _brand = brand
    } catch (error) {
      // hyprctl missing or not Hyprland: fail open rather than blanking the
      // widget over a filter the user only asked to narrow things with.
      _matched = true
      _brand = ""
    }
  }
}