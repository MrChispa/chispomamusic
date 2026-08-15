import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Volume for players that do not implement the MPRIS volume property.
//
// Browsers are the common case: they publish a full MPRIS session but leave
// volume out of it, so the popup would otherwise show no volume control at
// all. Driving the player's PipeWire playback stream instead moves exactly
// the knob a mixer would, which is as close to real volume as the browser
// route can get.
//
// The stream node only exists while audio is actually flowing, so this
// reports unavailable when playback is stopped — the slider hides rather
// than pretending to control something.
Item {
  id: root

  // MPRIS identity of the selected player, e.g. "Chromium".
  property string appHint: ""

  readonly property var node: findNode()
  readonly property bool available: node !== null && node.audio !== null
  readonly property real volume: available ? node.audio.volume : 0

  function setVolume(value) {
    if (root.available) root.node.audio.volume = Math.max(0, Math.min(1, value))
  }

  function overlaps(field, hint) {
    var value = String(field || "").trim().toLowerCase()
    if (value === "") return false
    // Either direction: PipeWire may report "chromium" where MPRIS says
    // "Chromium", or a binary "youtube-music" against the identity
    // "com.github.th-ch.youtube-music".
    return value.indexOf(hint) !== -1 || hint.indexOf(value) !== -1
  }

  // The process binary outranks the application name because Electron clients
  // report themselves as "Chromium" too — with a browser also running, the
  // name alone would happily pick the wrong stream.
  function scoreNode(candidate, hint) {
    var props = candidate.properties || {}
    if (overlaps(props["application.process.binary"], hint)) return 3
    if (overlaps(props["application.name"], hint)) return 2
    if (overlaps(candidate.name, hint)) return 1
    return 0
  }

  function findNode() {
    var hint = String(root.appHint).trim().toLowerCase()
    if (!Pipewire.ready || hint === "") return null

    var nodes = Pipewire.nodes.values
    var best = null
    var bestScore = 0

    for (var i = 0; i < nodes.length; i++) {
      var candidate = nodes[i]
      if (!candidate || !candidate.isStream) continue
      var score = scoreNode(candidate, hint)
      if (score > bestScore) {
        best = candidate
        bestScore = score
      }
    }
    return best
  }

  // Node properties stay stale unless the object is explicitly tracked.
  PwObjectTracker {
    objects: root.node ? [root.node] : []
  }
}
