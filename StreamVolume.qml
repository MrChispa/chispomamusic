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
//
// Node discovery is deliberately imperative rather than a readonly binding:
// a `readonly property var node: findNode()` binding evaluates once against
// the startup PipeWire state (often not ready, so null) and only re-runs if
// a dependency it tracked happens to change afterwards — in a stable session
// that may never happen, leaving the volume slider permanently hidden. We
// refresh explicitly from every event that can make the answer change
// (startup, hint change, node set change) and retry on a timer while the
// node is still missing.
Item {
  id: root

  // MPRIS identity of the selected player, e.g. "Chromium".
  property string appHint: ""

  property var node: null
  readonly property bool available: node !== null && node.audio !== null
  readonly property real volume: available ? node.audio.volume : 0

  // Kept as a binding so `onAllStreamsChanged` fires whenever the PipeWire
  // node model changes (the same reactivity the shell's audio panel relies
  // on); it is only used as a change trigger, not as a data source.
  readonly property var allStreams: Pipewire.nodes ? Pipewire.nodes.values : []
  onAllStreamsChanged: root.refresh()

  function setVolume(value) {
    if (root.available) root.node.audio.volume = Math.max(0, Math.min(1, value))
  }

  function refresh() {
    var next = root.findNode()
    if (next !== root.node) root.node = next
  }

  Component.onCompleted: root.refresh()
  onAppHintChanged: root.refresh()

  // PipeWire usually connects a moment after the panel appears; keep probing
  // while playback could be flowing but no stream node is bound yet.
  Timer {
    interval: 1200
    repeat: true
    running: !root.available && root.appHint !== ""
    onTriggered: root.refresh()
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
  // name alone would happily pick the wrong stream. The node name is the
  // reliable fallback when the properties are unavailable (they are not
  // populated until the node is bound).
  function scoreNode(candidate, hint) {
    var props = candidate.properties || {}
    if (overlaps(props["application.process.binary"], hint)) return 3
    if (overlaps(props["application.name"], hint)) return 2
    if (overlaps(candidate.name, hint)) return 1
    if (overlaps(candidate.type, hint)) return 1
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