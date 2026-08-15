// Player discovery for omamusic.
//
// YouTube Music has no single canonical Linux client, so we have to cope with
// two very different shapes of MPRIS session:
//
//   1. A native desktop client (th-ch/youtube-music, YTMDesktop). These
//      announce themselves properly through `identity` / `desktopEntry`.
//   2. A browser tab or PWA on music.youtube.com. The MPRIS session belongs to
//      the browser, so the identity is "Firefox"/"Chromium" and there is no URL
//      anywhere in the metadata. The only usable signal is the shape of the
//      metadata itself — see `looksLikeMusic`.
//
// Matching lives here rather than in Panel.qml so the rules stay readable.

// Substrings matched against identity and desktopEntry (both lowercased).
var NATIVE_NAMES = [
  "youtube music",
  "youtube-music",
  "youtubemusic",
  "youtube_music",
  "ytmdesktop",
  "ytmd",
  // th-ch/youtube-music was renamed to pear-devs/pear-desktop in 2026 and
  // newer builds may announce themselves under the new name.
  "pear desktop",
  "pear-desktop"
]

var BROWSER_NAMES = [
  "firefox",
  "librewolf",
  "waterfox",
  "floorp",
  "zen browser",
  "mozilla",
  "chromium",
  "chrome",
  "brave",
  "vivaldi",
  "edge",
  "opera",
  "epiphany",
  "gnome web",
  "webkit"
]

function norm(value) {
  return (value === undefined || value === null) ? "" : String(value).trim().toLowerCase()
}

// "youtube music, my player" -> ["youtube music", "my player"]
function parseNames(raw) {
  var out = []
  if (!raw) return out
  var parts = String(raw).split(",")
  for (var i = 0; i < parts.length; i++) {
    var name = norm(parts[i])
    if (name.length > 0) out.push(name)
  }
  return out
}

function matchesName(player, names) {
  var identity = norm(player.identity)
  var entry = norm(player.desktopEntry)
  for (var i = 0; i < names.length; i++) {
    var needle = names[i]
    if (needle.length === 0) continue
    if (identity.indexOf(needle) !== -1) return true
    if (entry.length > 0 && entry.indexOf(needle) !== -1) return true
  }
  return false
}

function isNative(player, extraNames) {
  return matchesName(player, NATIVE_NAMES.concat(extraNames || []))
}

function isBrowser(player) {
  return matchesName(player, BROWSER_NAMES)
}

// Browsers expose one MPRIS session for whatever media is active, with no hint
// about which site it came from. YouTube Music fills the MediaSession metadata
// with artist *and* album; plain YouTube videos, podcasts and video players
// almost always leave album empty. Strict mode requires both, which is a
// heuristic, not a guarantee — hence the setting.
function looksLikeMusic(player, strict) {
  if (norm(player.trackArtist).length === 0) return false
  if (!strict) return true
  return norm(player.trackAlbum).length > 0
}

function preferPlaying(candidates) {
  if (candidates.length === 0) return null
  for (var i = 0; i < candidates.length; i++) {
    if (candidates[i].isPlaying) return candidates[i]
  }
  return candidates[0]
}

// Both routes below speak MPRIS — the browser exposes a session just like a
// native client does. What differs is how much of the interface each one
// implements, which is why the choice is about *source*, not protocol.
// Accepts the manifest's enum labels as well as bare keywords.
function normalizeSource(value) {
  var source = norm(value)
  if (source.indexOf("native") !== -1) return "native"
  if (source.indexOf("browser") !== -1) return "browser"
  return "auto"
}

// `players` is Mpris.players.values. `options` accepts:
//   playerSource (string), strictBrowserMatch (bool), extraPlayerNames (string)
function selectPlayer(players, options) {
  if (!players || players.length === 0) return null
  var opts = options || {}
  var extra = parseNames(opts.extraPlayerNames)
  var strict = opts.strictBrowserMatch !== false
  var source = normalizeSource(opts.playerSource)

  var natives = []
  var browsers = []

  for (var i = 0; i < players.length; i++) {
    var player = players[i]
    if (!player) continue
    if (isNative(player, extra)) {
      if (source !== "browser") natives.push(player)
    } else if (source !== "native" && isBrowser(player) && looksLikeMusic(player, strict)) {
      browsers.push(player)
    }
  }

  return preferPlaying(natives) || preferPlaying(browsers)
}

// Shown under the controls so it is obvious *which* session is being driven —
// the browser fallback is a heuristic and users deserve to see when it fired.
function sourceLabel(player, extraPlayerNames) {
  if (!player) return ""
  if (isNative(player, parseNames(extraPlayerNames))) return ""
  return "via " + (player.identity || "browser")
}

function formatTime(seconds) {
  if (!seconds || seconds <= 0 || !isFinite(seconds)) return "0:00"
  var total = Math.floor(seconds)
  var hours = Math.floor(total / 3600)
  var minutes = Math.floor((total % 3600) / 60)
  var secs = total % 60
  var padded = (secs < 10 ? "0" : "") + secs
  if (hours > 0) return hours + ":" + (minutes < 10 ? "0" : "") + minutes + ":" + padded
  return minutes + ":" + padded
}
